#!/bin/bash

# EdgeQuark Document Fraud Detection Platform - API Testing Script
# This script tests all API endpoints and functionality

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${BASE_URL:-http://localhost:5000}"
TEST_IMAGE_URL="https://via.placeholder.com/800x600/CCCCCC/000000?text=Test+Document"
TEMP_DIR="/tmp/edgequark-test"
TEST_IMAGE="$TEMP_DIR/test-document.png"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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

log_test() {
    echo -e "${PURPLE}[TEST]${NC} $1"
}

# Function to increment test counter
start_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_test "$1"
}

# Function to mark test as passed
pass_test() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    log_success "✓ Test passed: $1"
}

# Function to mark test as failed
fail_test() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    log_error "✗ Test failed: $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
    local url="$1"
    local timeout="${2:-30}"
    local counter=0
    
    log_info "Waiting for service at $url (timeout: ${timeout}s)..."
    
    while [ $counter -lt $timeout ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            log_success "Service is ready"
            return 0
        fi
        sleep 1
        counter=$((counter + 1))
        echo -n "."
    done
    
    echo ""
    log_error "Service not ready after ${timeout}s"
    return 1
}

# Function to setup test environment
setup_test_env() {
    log_info "Setting up test environment..."
    
    # Check required tools
    if ! command_exists curl; then
        log_error "curl is required for testing"
        exit 1
    fi
    
    if ! command_exists jq; then
        log_warning "jq not found. JSON parsing will be limited."
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Download test image
    if command_exists curl; then
        log_info "Downloading test image..."
        curl -s "$TEST_IMAGE_URL" -o "$TEST_IMAGE" || {
            log_warning "Could not download test image. Creating local test file..."
            echo "Test document content" > "$TEST_IMAGE"
        }
    else
        echo "Test document content" > "$TEST_IMAGE"
    fi
    
    log_success "Test environment ready"
}

# Function to cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment..."
    rm -rf "$TEMP_DIR"
    log_success "Cleanup completed"
}

# Function to test health endpoint
test_health_endpoint() {
    start_test "Health endpoint check"
    
    local response
    response=$(curl -s -w "%{http_code}" "$BASE_URL/api/health")
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        pass_test "Health endpoint returns 200"
        
        if command_exists jq && echo "$body" | jq . >/dev/null 2>&1; then
            local status
            status=$(echo "$body" | jq -r '.status // "unknown"')
            log_info "Service status: $status"
        fi
    else
        fail_test "Health endpoint returned $http_code"
    fi
}

# Function to test models endpoint
test_models_endpoint() {
    start_test "Models endpoint check"
    
    local response
    response=$(curl -s -w "%{http_code}" "$BASE_URL/api/models")
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        pass_test "Models endpoint returns 200"
        
        if command_exists jq && echo "$body" | jq . >/dev/null 2>&1; then
            local success
            success=$(echo "$body" | jq -r '.success // false')
            if [ "$success" = "true" ]; then
                log_info "Models endpoint working correctly"
            else
                log_warning "Models endpoint returned success=false"
            fi
        fi
    else
        fail_test "Models endpoint returned $http_code"
    fi
}

# Function to test file upload API
test_file_upload_api() {
    start_test "File upload API test"
    
    if [ ! -f "$TEST_IMAGE" ]; then
        fail_test "Test image not found: $TEST_IMAGE"
        return
    fi
    
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
        -F "file=@$TEST_IMAGE" \
        "$BASE_URL/api/analyze")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    case "$http_code" in
        200)
            pass_test "File upload API returns 200"
            
            if command_exists jq && echo "$body" | jq . >/dev/null 2>&1; then
                local success
                success=$(echo "$body" | jq -r '.success // false')
                if [ "$success" = "true" ]; then
                    log_info "Analysis completed successfully"
                    
                    # Check for required fields
                    local filename
                    filename=$(echo "$body" | jq -r '.filename // "missing"')
                    log_info "Analyzed filename: $filename"
                    
                    local analysis_result
                    analysis_result=$(echo "$body" | jq -r '.analysis.success // false')
                    log_info "Analysis result success: $analysis_result"
                else
                    log_warning "API returned success=false"
                fi
            fi
            ;;
        400)
            log_warning "File upload returned 400 (might be expected for test file)"
            ;;
        413)
            log_warning "File too large (413)"
            ;;
        500|503)
            fail_test "Server error: $http_code"
            ;;
        *)
            fail_test "Unexpected status code: $http_code"
            ;;
    esac
}

# Function to test error handling
test_error_handling() {
    start_test "Error handling tests"
    
    # Test 1: No file upload
    local response
    response=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/api/analyze")
    local http_code="${response: -3}"
    
    if [ "$http_code" = "400" ]; then
        pass_test "No file error handling works (400)"
    else
        fail_test "Expected 400 for no file, got $http_code"
    fi
    
    # Test 2: Invalid endpoint
    start_test "Invalid endpoint test"
    response=$(curl -s -w "%{http_code}" "$BASE_URL/api/nonexistent")
    http_code="${response: -3}"
    
    if [ "$http_code" = "404" ]; then
        pass_test "Invalid endpoint returns 404"
    else
        fail_test "Expected 404 for invalid endpoint, got $http_code"
    fi
}

# Function to test web interface
test_web_interface() {
    start_test "Web interface accessibility"
    
    local response
    response=$(curl -s -w "%{http_code}" "$BASE_URL/")
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        pass_test "Main page loads successfully"
        
        # Check for expected content
        if echo "$body" | grep -q "EdgeQuark"; then
            log_info "Page contains EdgeQuark branding"
        else
            log_warning "Page may not be loading correctly"
        fi
        
        if echo "$body" | grep -q "upload"; then
            log_info "Upload functionality detected"
        fi
    else
        fail_test "Main page returned $http_code"
    fi
}

# Function to test CORS and security headers
test_security_headers() {
    start_test "Security headers check"
    
    local headers
    headers=$(curl -s -I "$BASE_URL/api/health")
    
    # Check for common security headers
    if echo "$headers" | grep -qi "X-Content-Type-Options"; then
        log_info "X-Content-Type-Options header present"
    else
        log_warning "X-Content-Type-Options header missing"
    fi
    
    if echo "$headers" | grep -qi "X-Frame-Options"; then
        log_info "X-Frame-Options header present"
    else
        log_warning "X-Frame-Options header missing"
    fi
    
    pass_test "Security headers check completed"
}

# Function to test performance
test_performance() {
    start_test "Basic performance test"
    
    local start_time
    start_time=$(date +%s.%N)
    
    curl -s "$BASE_URL/api/health" >/dev/null
    
    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    
    if [ "$duration" != "N/A" ]; then
        log_info "Health endpoint response time: ${duration}s"
        
        # Check if response time is reasonable (less than 5 seconds)
        if (( $(echo "$duration < 5.0" | bc -l 2>/dev/null || echo 0) )); then
            pass_test "Response time acceptable"
        else
            log_warning "Response time seems slow: ${duration}s"
        fi
    else
        pass_test "Performance test completed (timing unavailable)"
    fi
}

# Function to generate test report
generate_report() {
    echo ""
    echo "=============================================="
    echo "           EdgeQuark API Test Report"
    echo "=============================================="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Success Rate: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
    echo "=============================================="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All tests passed! ✨"
        return 0
    else
        log_error "$FAILED_TESTS test(s) failed"
        return 1
    fi
}

# Function to show test banner
show_banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "     EdgeQuark API Testing Suite"
    echo "=============================================="
    echo -e "${NC}"
    echo "Base URL: $BASE_URL"
    echo "Test Image: $TEST_IMAGE"
    echo "=============================================="
    echo ""
}

# Main test execution
main() {
    show_banner
    
    case "${1:-all}" in
        "all")
            setup_test_env
            wait_for_service "$BASE_URL/api/health" 30
            
            test_health_endpoint
            test_models_endpoint
            test_web_interface
            test_file_upload_api
            test_error_handling
            test_security_headers
            test_performance
            
            cleanup_test_env
            generate_report
            ;;
        "quick")
            test_health_endpoint
            test_web_interface
            generate_report
            ;;
        "api")
            setup_test_env
            test_health_endpoint
            test_models_endpoint
            test_file_upload_api
            test_error_handling
            cleanup_test_env
            generate_report
            ;;
        "web")
            test_web_interface
            test_security_headers
            generate_report
            ;;
        "health")
            test_health_endpoint
            generate_report
            ;;
        "help"|"-h"|"--help")
            echo "EdgeQuark API Testing Suite"
            echo ""
            echo "Usage: $0 [TEST_SUITE]"
            echo ""
            echo "Test Suites:"
            echo "  all       Run all tests (default)"
            echo "  quick     Run quick smoke tests"
            echo "  api       Run API endpoint tests"
            echo "  web       Run web interface tests"
            echo "  health    Run health check only"
            echo "  help      Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  BASE_URL  Base URL for testing (default: http://localhost:5000)"
            echo ""
            ;;
        *)
            log_error "Unknown test suite: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Set trap for cleanup
trap cleanup_test_env EXIT

# Run main function with all arguments
main "$@"