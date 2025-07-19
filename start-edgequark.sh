#!/bin/bash

# EdgeQuark Document Fraud Detection Platform - Startup Script
# This script starts the EdgeQuark platform with proper environment setup

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/edgequark-env"
LOG_DIR="$SCRIPT_DIR/logs"
APP_FILE="$SCRIPT_DIR/app.py"

# Default environment variables
export FLASK_APP="app.py"
export FLASK_ENV="${FLASK_ENV:-production}"
export PORT="${PORT:-5000}"
export HOST="${HOST:-0.0.0.0}"
export OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
export OLLAMA_MODEL="${OLLAMA_MODEL:-edgequark}"
export SECRET_KEY="${SECRET_KEY:-$(openssl rand -hex 32)}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is available
port_available() {
    ! nc -z localhost "$1" 2>/dev/null
}

# Function to check Ollama service
check_ollama() {
    log_info "Checking Ollama service..."
    
    if ! command_exists curl; then
        log_warning "curl not found. Cannot check Ollama status."
        return 1
    fi
    
    if curl -s "$OLLAMA_BASE_URL/api/tags" >/dev/null 2>&1; then
        log_success "Ollama service is running at $OLLAMA_BASE_URL"
        
        # Check if EdgeQuark model is available
        if curl -s "$OLLAMA_BASE_URL/api/tags" | grep -q "$OLLAMA_MODEL"; then
            log_success "EdgeQuark model '$OLLAMA_MODEL' is available"
        else
            log_warning "EdgeQuark model '$OLLAMA_MODEL' not found"
            log_info "Available models:"
            curl -s "$OLLAMA_BASE_URL/api/tags" | python3 -m json.tool 2>/dev/null || echo "Could not parse model list"
        fi
        return 0
    else
        log_error "Ollama service is not accessible at $OLLAMA_BASE_URL"
        log_info "Please ensure Ollama is running and accessible"
        return 1
    fi
}

# Function to setup virtual environment
setup_venv() {
    log_info "Setting up Python virtual environment..."
    
    if [ ! -d "$VENV_DIR" ]; then
        log_info "Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
    fi
    
    log_info "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
    
    log_info "Installing/updating dependencies..."
    pip install --upgrade pip
    pip install flask requests python-magic werkzeug gunicorn
    
    log_success "Virtual environment ready"
}

# Function to check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check Python
    if ! command_exists python3; then
        log_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check Python version
    python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    log_info "Python version: $python_version"
    
    # Check if app file exists
    if [ ! -f "$APP_FILE" ]; then
        log_error "Application file not found: $APP_FILE"
        exit 1
    fi
    
    # Check port availability
    if ! port_available "$PORT"; then
        log_error "Port $PORT is already in use"
        log_info "Please stop the service using that port or set a different PORT environment variable"
        exit 1
    fi
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    log_success "System requirements check passed"
}

# Function to start the application
start_application() {
    log_info "Starting EdgeQuark Document Fraud Detection Platform..."
    
    cd "$SCRIPT_DIR"
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Start application based on environment
    if [ "$FLASK_ENV" = "development" ]; then
        log_info "Starting in development mode..."
        python3 "$APP_FILE"
    else
        log_info "Starting in production mode with Gunicorn..."
        
        # Create gunicorn configuration
        cat > "$SCRIPT_DIR/gunicorn.conf.py" << EOF
bind = "$HOST:$PORT"
workers = 4
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 120
keepalive = 2
preload_app = True
accesslog = "$LOG_DIR/access.log"
errorlog = "$LOG_DIR/error.log"
loglevel = "info"
EOF
        
        # Start with Gunicorn
        gunicorn --config gunicorn.conf.py app:app
    fi
}

# Function to display startup banner
show_banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "   EdgeQuark Document Fraud Detection"
    echo "=============================================="
    echo -e "${NC}"
    echo "Version: 1.0.0"
    echo "Environment: $FLASK_ENV"
    echo "Host: $HOST"
    echo "Port: $PORT"
    echo "Ollama URL: $OLLAMA_BASE_URL"
    echo "Model: $OLLAMA_MODEL"
    echo "Log Directory: $LOG_DIR"
    echo "=============================================="
    echo ""
}

# Function to handle cleanup on exit
cleanup() {
    log_info "Shutting down EdgeQuark platform..."
    # Kill any background processes if needed
    exit 0
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main execution
main() {
    show_banner
    
    # Parse command line arguments
    case "${1:-start}" in
        "start")
            check_requirements
            setup_venv
            check_ollama
            start_application
            ;;
        "check")
            check_requirements
            check_ollama
            log_success "All checks passed"
            ;;
        "setup")
            check_requirements
            setup_venv
            log_success "Setup completed"
            ;;
        "status")
            if port_available "$PORT"; then
                log_info "EdgeQuark platform is not running on port $PORT"
            else
                log_success "EdgeQuark platform is running on port $PORT"
                if command_exists curl; then
                    log_info "Testing health endpoint..."
                    curl -s "http://localhost:$PORT/api/health" | python3 -m json.tool 2>/dev/null || log_warning "Health check failed"
                fi
            fi
            check_ollama
            ;;
        "stop")
            log_info "Stopping EdgeQuark platform..."
            pkill -f "python.*app.py" 2>/dev/null || log_info "No Python app processes found"
            pkill -f "gunicorn.*app:app" 2>/dev/null || log_info "No Gunicorn processes found"
            log_success "EdgeQuark platform stopped"
            ;;
        "restart")
            $0 stop
            sleep 2
            $0 start
            ;;
        "logs")
            if [ -f "$LOG_DIR/edgequark.log" ]; then
                tail -f "$LOG_DIR/edgequark.log"
            else
                log_warning "Log file not found: $LOG_DIR/edgequark.log"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "EdgeQuark Document Fraud Detection Platform"
            echo ""
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  start     Start the EdgeQuark platform (default)"
            echo "  stop      Stop the EdgeQuark platform"
            echo "  restart   Restart the EdgeQuark platform"
            echo "  status    Check platform and service status"
            echo "  check     Run system checks"
            echo "  setup     Setup virtual environment and dependencies"
            echo "  logs      Show application logs"
            echo "  help      Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  FLASK_ENV       Application environment (development/production)"
            echo "  PORT           Port to run the application on (default: 5000)"
            echo "  HOST           Host to bind to (default: 0.0.0.0)"
            echo "  OLLAMA_BASE_URL URL for Ollama API (default: http://localhost:11434)"
            echo "  OLLAMA_MODEL    Model name to use (default: edgequark)"
            echo "  SECRET_KEY      Flask secret key (auto-generated if not set)"
            echo ""
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"