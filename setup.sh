#!/bin/bash

# EdgeQuark Document Fraud Detection Platform - Setup Script
# This script performs complete installation and configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/edgequark-env"
SERVICE_NAME="edgequark"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
USER=$(whoami)
PYTHON_VERSION_REQUIRED="3.8"

# Installation options
INSTALL_SYSTEMD=${INSTALL_SYSTEMD:-true}
INSTALL_DEPENDENCIES=${INSTALL_DEPENDENCIES:-true}
SETUP_FIREWALL=${SETUP_FIREWALL:-false}
ENABLE_AUTOSTART=${ENABLE_AUTOSTART:-true}

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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_cmd() {
    echo -e "${CYAN}[CMD]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. Some operations will be adjusted accordingly."
        return 0
    else
        return 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to compare version numbers
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        OS="Red Hat Enterprise Linux"
        VER=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    log_info "Detected OS: $OS $VER"
}

# Function to install system dependencies
install_system_dependencies() {
    log_step "Installing system dependencies..."
    
    detect_os
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            log_cmd "apt update && apt install -y python3 python3-pip python3-venv python3-dev libmagic1 curl jq bc netcat-openbsd"
            if check_root; then
                apt update
                apt install -y python3 python3-pip python3-venv python3-dev libmagic1 curl jq bc netcat-openbsd
            else
                sudo apt update
                sudo apt install -y python3 python3-pip python3-venv python3-dev libmagic1 curl jq bc netcat-openbsd
            fi
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            log_cmd "yum install -y python3 python3-pip python3-devel file-libs curl jq bc nmap-ncat"
            if check_root; then
                yum install -y python3 python3-pip python3-devel file-libs curl jq bc nmap-ncat
            else
                sudo yum install -y python3 python3-pip python3-devel file-libs curl jq bc nmap-ncat
            fi
            ;;
        *"Fedora"*)
            log_cmd "dnf install -y python3 python3-pip python3-devel file-libs curl jq bc nmap-ncat"
            if check_root; then
                dnf install -y python3 python3-pip python3-devel file-libs curl jq bc nmap-ncat
            else
                sudo dnf install -y python3 python3-pip python3-devel file-libs curl jq bc nmap-ncat
            fi
            ;;
        *"Arch"*)
            log_cmd "pacman -S --noconfirm python python-pip file curl jq bc gnu-netcat"
            if check_root; then
                pacman -S --noconfirm python python-pip file curl jq bc gnu-netcat
            else
                sudo pacman -S --noconfirm python python-pip file curl jq bc gnu-netcat
            fi
            ;;
        *)
            log_warning "Unknown OS. Please install Python 3.8+, pip, venv, libmagic, curl, jq, bc, and netcat manually."
            ;;
    esac
    
    log_success "System dependencies installed"
}

# Function to check Python version
check_python_version() {
    log_step "Checking Python version..."
    
    if ! command_exists python3; then
        log_error "Python 3 is not installed"
        return 1
    fi
    
    local python_version
    python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    log_info "Python version: $python_version"
    
    if version_gt "$PYTHON_VERSION_REQUIRED" "$python_version"; then
        log_error "Python $PYTHON_VERSION_REQUIRED or higher is required. Found: $python_version"
        return 1
    fi
    
    log_success "Python version check passed"
}

# Function to setup virtual environment
setup_virtual_environment() {
    log_step "Setting up Python virtual environment..."
    
    # Remove existing venv if it exists
    if [ -d "$VENV_DIR" ]; then
        log_warning "Existing virtual environment found. Removing..."
        rm -rf "$VENV_DIR"
    fi
    
    # Create new virtual environment
    log_cmd "python3 -m venv $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    log_cmd "pip install --upgrade pip"
    pip install --upgrade pip
    
    # Install Python dependencies
    log_cmd "pip install flask requests python-magic werkzeug gunicorn"
    pip install flask requests python-magic werkzeug gunicorn
    
    log_success "Virtual environment setup completed"
}

# Function to setup configuration files
setup_configuration() {
    log_step "Setting up configuration files..."
    
    # Create environment file
    cat > "$SCRIPT_DIR/.env" << EOF
# EdgeQuark Document Fraud Detection Platform Configuration
# Copy this file to .env.local and customize as needed

# Flask Configuration
FLASK_ENV=production
SECRET_KEY=$(openssl rand -hex 32)
PORT=5000
HOST=0.0.0.0

# Ollama Configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=edgequark

# Logging
LOG_LEVEL=INFO

# Security
MAX_CONTENT_LENGTH=16777216

# Performance
WORKERS=4
TIMEOUT=120
EOF
    
    # Create requirements.txt
    cat > "$SCRIPT_DIR/requirements.txt" << EOF
flask>=2.0.0
requests>=2.25.0
python-magic>=0.4.0
werkzeug>=2.0.0
gunicorn>=20.0.0
EOF
    
    log_success "Configuration files created"
}

# Function to create systemd service
create_systemd_service() {
    if [ "$INSTALL_SYSTEMD" != "true" ]; then
        log_info "Skipping systemd service creation"
        return 0
    fi
    
    log_step "Creating systemd service..."
    
    # Check if we can create system service
    if ! check_root && ! sudo -n true 2>/dev/null; then
        log_warning "Cannot create system service without sudo privileges"
        log_info "You can create the service manually later using:"
        log_info "sudo cp $SCRIPT_DIR/edgequark.service $SERVICE_FILE"
        log_info "sudo systemctl daemon-reload"
        log_info "sudo systemctl enable $SERVICE_NAME"
        return 0
    fi
    
    # Create service file content
    cat > "$SCRIPT_DIR/edgequark.service" << EOF
[Unit]
Description=EdgeQuark Document Fraud Detection Platform
After=network.target
Wants=network.target

[Service]
Type=notify
User=$USER
Group=$USER
WorkingDirectory=$SCRIPT_DIR
Environment=PATH=$VENV_DIR/bin
ExecStart=$VENV_DIR/bin/gunicorn --config gunicorn.conf.py app:app
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=on-failure
RestartSec=10

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$SCRIPT_DIR/logs $SCRIPT_DIR/uploads
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Install service file
    if check_root; then
        cp "$SCRIPT_DIR/edgequark.service" "$SERVICE_FILE"
    else
        sudo cp "$SCRIPT_DIR/edgequark.service" "$SERVICE_FILE"
    fi
    
    # Reload systemd and enable service
    if check_root; then
        systemctl daemon-reload
        if [ "$ENABLE_AUTOSTART" = "true" ]; then
            systemctl enable "$SERVICE_NAME"
            log_success "Systemd service created and enabled"
        else
            log_success "Systemd service created (not enabled for autostart)"
        fi
    else
        sudo systemctl daemon-reload
        if [ "$ENABLE_AUTOSTART" = "true" ]; then
            sudo systemctl enable "$SERVICE_NAME"
            log_success "Systemd service created and enabled"
        else
            log_success "Systemd service created (not enabled for autostart)"
        fi
    fi
}

# Function to setup firewall
setup_firewall() {
    if [ "$SETUP_FIREWALL" != "true" ]; then
        log_info "Skipping firewall setup"
        return 0
    fi
    
    log_step "Setting up firewall..."
    
    local port="${PORT:-5000}"
    
    if command_exists ufw; then
        log_cmd "ufw allow $port"
        if check_root; then
            ufw allow "$port"
        else
            sudo ufw allow "$port"
        fi
        log_success "UFW firewall rule added for port $port"
    elif command_exists firewall-cmd; then
        log_cmd "firewall-cmd --permanent --add-port=$port/tcp"
        if check_root; then
            firewall-cmd --permanent --add-port="$port"/tcp
            firewall-cmd --reload
        else
            sudo firewall-cmd --permanent --add-port="$port"/tcp
            sudo firewall-cmd --reload
        fi
        log_success "Firewalld rule added for port $port"
    else
        log_warning "No supported firewall found (ufw/firewalld)"
    fi
}

# Function to setup log rotation
setup_log_rotation() {
    log_step "Setting up log rotation..."
    
    # Create logrotate configuration
    cat > "$SCRIPT_DIR/logrotate.conf" << EOF
$SCRIPT_DIR/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        systemctl reload $SERVICE_NAME >/dev/null 2>&1 || true
    endscript
}
EOF
    
    # Install logrotate configuration
    if check_root; then
        cp "$SCRIPT_DIR/logrotate.conf" "/etc/logrotate.d/$SERVICE_NAME"
    elif sudo -n true 2>/dev/null; then
        sudo cp "$SCRIPT_DIR/logrotate.conf" "/etc/logrotate.d/$SERVICE_NAME"
    else
        log_warning "Cannot install logrotate config without sudo. Manual installation required:"
        log_info "sudo cp $SCRIPT_DIR/logrotate.conf /etc/logrotate.d/$SERVICE_NAME"
    fi
    
    log_success "Log rotation configured"
}

# Function to run tests
run_tests() {
    log_step "Running basic tests..."
    
    # Test Python imports
    source "$VENV_DIR/bin/activate"
    
    python3 -c "import flask, requests, magic, werkzeug" || {
        log_error "Failed to import required Python modules"
        return 1
    }
    
    # Test application startup (dry run)
    python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
try:
    from app import app
    print('Flask application imports successfully')
except Exception as e:
    print(f'Failed to import Flask application: {e}')
    sys.exit(1)
"
    
    log_success "Basic tests passed"
}

# Function to display post-installation instructions
show_instructions() {
    echo ""
    echo "=============================================="
    echo "     EdgeQuark Installation Complete!"
    echo "=============================================="
    echo ""
    echo "🚀 Quick Start:"
    echo "   cd $SCRIPT_DIR"
    echo "   ./start-edgequark.sh"
    echo ""
    echo "🔧 Service Management:"
    if [ "$INSTALL_SYSTEMD" = "true" ]; then
        echo "   sudo systemctl start $SERVICE_NAME"
        echo "   sudo systemctl stop $SERVICE_NAME"
        echo "   sudo systemctl restart $SERVICE_NAME"
        echo "   sudo systemctl status $SERVICE_NAME"
    else
        echo "   ./start-edgequark.sh start"
        echo "   ./start-edgequark.sh stop"
        echo "   ./start-edgequark.sh restart"
        echo "   ./start-edgequark.sh status"
    fi
    echo ""
    echo "🧪 Testing:"
    echo "   ./test-api.sh"
    echo ""
    echo "📝 Configuration:"
    echo "   Edit $SCRIPT_DIR/.env for custom settings"
    echo ""
    echo "📊 Monitoring:"
    echo "   Logs: $SCRIPT_DIR/logs/"
    echo "   Health: http://localhost:5000/api/health"
    echo ""
    echo "⚠️  Important Notes:"
    echo "   • Ensure Ollama is running with EdgeQuark model"
    echo "   • Configure firewall if needed (port 5000)"
    echo "   • Review security settings for production use"
    echo ""
    echo "🔗 Useful Commands:"
    echo "   ./start-edgequark.sh help    # Show all options"
    echo "   ./test-api.sh help           # Testing options"
    echo ""
    echo "=============================================="
}

# Function to show setup banner
show_banner() {
    echo -e "${CYAN}"
    echo "=============================================="
    echo "    EdgeQuark Setup & Installation"
    echo "=============================================="
    echo -e "${NC}"
    echo "Version: 1.0.0"
    echo "Platform: $(uname -s) $(uname -m)"
    echo "User: $USER"
    echo "Directory: $SCRIPT_DIR"
    echo "=============================================="
    echo ""
}

# Main setup function
main() {
    show_banner
    
    case "${1:-full}" in
        "full")
            if [ "$INSTALL_DEPENDENCIES" = "true" ]; then
                install_system_dependencies
            fi
            check_python_version
            setup_virtual_environment
            setup_configuration
            create_systemd_service
            setup_firewall
            setup_log_rotation
            run_tests
            show_instructions
            ;;
        "minimal")
            check_python_version
            setup_virtual_environment
            setup_configuration
            run_tests
            log_success "Minimal setup completed"
            ;;
        "deps")
            install_system_dependencies
            check_python_version
            log_success "Dependencies installed"
            ;;
        "venv")
            check_python_version
            setup_virtual_environment
            log_success "Virtual environment setup completed"
            ;;
        "service")
            create_systemd_service
            log_success "Systemd service setup completed"
            ;;
        "test")
            run_tests
            ;;
        "help"|"-h"|"--help")
            echo "EdgeQuark Setup Script"
            echo ""
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  full      Complete installation (default)"
            echo "  minimal   Basic setup without system integration"
            echo "  deps      Install system dependencies only"
            echo "  venv      Setup virtual environment only"
            echo "  service   Setup systemd service only"
            echo "  test      Run tests only"
            echo "  help      Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  INSTALL_SYSTEMD=true     Install systemd service"
            echo "  INSTALL_DEPENDENCIES=true Install system packages"
            echo "  SETUP_FIREWALL=false     Configure firewall rules"
            echo "  ENABLE_AUTOSTART=true    Enable service autostart"
            echo ""
            echo "Examples:"
            echo "  $0                       # Full installation"
            echo "  $0 minimal               # Basic setup only"
            echo "  SETUP_FIREWALL=true $0   # Install with firewall"
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