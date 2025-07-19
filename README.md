# EdgeQuark Document Fraud Detection Platform

A production-ready AI-powered document fraud detection platform built with Flask and integrated with EdgeQuark AI via Ollama API.

## 🚀 Quick Start

```bash
# Clone or navigate to the platform directory
cd /home/alen/edgequark-platform

# Run the setup script
./setup.sh

# Start the platform
./start-edgequark.sh
```

The platform will be available at `http://localhost:5000`

## 📁 Directory Structure

```
edgequark-platform/
├── app.py                 # Main Flask application
├── templates/             # HTML templates
│   ├── base.html         # Base template with styling
│   ├── index.html        # Upload interface
│   └── results.html      # Analysis results display
├── static/               # CSS/JS assets
│   └── css/
│       └── style.css     # Custom styling
├── logs/                 # Application logs
├── uploads/              # Temporary upload directory
├── edgequark-env/        # Python virtual environment
├── start-edgequark.sh    # Startup script
├── test-api.sh          # API testing script
├── setup.sh             # Installation script
├── edgequark.service    # Systemd service file
├── gunicorn.conf.py     # Gunicorn configuration
└── README.md            # This file
```

## 🔧 Features

### Core Functionality
- **Document Upload**: Support for PNG, JPEG, GIF, BMP, TIFF, and PDF files
- **AI Analysis**: Integration with EdgeQuark AI model via Ollama API
- **Fraud Detection**: Comprehensive analysis of document authenticity
- **Real-time Results**: Instant analysis with detailed fraud indicators
- **Web Interface**: User-friendly upload and results interface
- **RESTful API**: Complete API for programmatic access

### Security Features
- **File Validation**: Strict file type and size validation (16MB limit)
- **Input Sanitization**: Secure filename handling and path validation
- **Error Handling**: Comprehensive error handling and logging
- **Production Security**: Systemd service with security hardening

### Technical Features
- **Production Ready**: Gunicorn WSGI server with proper configuration
- **Logging**: Comprehensive logging with rotation support
- **Health Monitoring**: Health check endpoints for monitoring
- **Testing Suite**: Comprehensive API testing scripts
- **Service Management**: Systemd service for production deployment

## 🛠 Installation

### Prerequisites
- Python 3.8 or higher
- Ollama with EdgeQuark model
- System dependencies (installed automatically)

### Automatic Installation
```bash
./setup.sh full
```

### Manual Installation
```bash
# Install system dependencies
./setup.sh deps

# Setup virtual environment
./setup.sh venv

# Setup systemd service
./setup.sh service
```

## 🚦 Usage

### Starting the Platform

**Development Mode:**
```bash
FLASK_ENV=development ./start-edgequark.sh
```

**Production Mode:**
```bash
./start-edgequark.sh
```

**Using Systemd:**
```bash
sudo systemctl start edgequark
sudo systemctl enable edgequark  # Enable autostart
```

### Management Commands

```bash
# Check status
./start-edgequark.sh status

# View logs
./start-edgequark.sh logs

# Stop service
./start-edgequark.sh stop

# Restart service
./start-edgequark.sh restart
```

### Testing

```bash
# Run all tests
./test-api.sh

# Quick smoke test
./test-api.sh quick

# API tests only
./test-api.sh api

# Web interface tests
./test-api.sh web
```

## 🔌 API Endpoints

### Health Check
```bash
GET /api/health
```
Returns service health status and Ollama connectivity.

### Document Analysis
```bash
POST /api/analyze
Content-Type: multipart/form-data

Parameters:
- file: Document file (image or PDF)
```

### Available Models
```bash
GET /api/models
```
Returns list of available Ollama models.

### Example API Usage

```bash
# Health check
curl http://localhost:5000/api/health

# Analyze document
curl -X POST -F "file=@document.png" http://localhost:5000/api/analyze

# Check available models
curl http://localhost:5000/api/models
```

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLASK_ENV` | production | Flask environment |
| `PORT` | 5000 | Server port |
| `HOST` | 0.0.0.0 | Server host |
| `OLLAMA_BASE_URL` | http://localhost:11434 | Ollama API URL |
| `OLLAMA_MODEL` | edgequark | AI model name |
| `SECRET_KEY` | auto-generated | Flask secret key |
| `WORKERS` | auto | Gunicorn worker count |
| `TIMEOUT` | 120 | Request timeout |

### Configuration Files

- **`.env`**: Environment variables
- **`gunicorn.conf.py`**: Gunicorn server configuration
- **`edgequark.service`**: Systemd service definition

## 📊 Monitoring

### Logs
- **Application**: `/home/alen/edgequark-platform/logs/edgequark.log`
- **Access**: `/home/alen/edgequark-platform/logs/access.log`
- **Error**: `/home/alen/edgequark-platform/logs/error.log`

### Health Monitoring
```bash
# Service status
systemctl status edgequark

# Application health
curl http://localhost:5000/api/health

# View real-time logs
journalctl -u edgequark -f
```

## 🔐 Security

### Production Security Features
- Systemd service hardening with restricted permissions
- Input validation and file type verification
- Secure file handling with temporary storage
- Request size limits and timeouts
- Comprehensive error handling without information disclosure

### Security Considerations
- Review and customize systemd service security settings
- Configure firewall rules for port 5000
- Use HTTPS in production with reverse proxy
- Regularly update dependencies and AI models
- Monitor logs for security events

## 🚨 Troubleshooting

### Common Issues

**Service won't start:**
```bash
# Check service status
sudo systemctl status edgequark

# Check logs
sudo journalctl -u edgequark -n 50
```

**Ollama connection failed:**
```bash
# Verify Ollama is running
curl http://localhost:11434/api/tags

# Check EdgeQuark model availability
curl http://localhost:11434/api/tags | grep edgequark
```

**Permission denied:**
```bash
# Fix file permissions
chmod +x *.sh
chown -R $USER:$USER /home/alen/edgequark-platform
```

**Port already in use:**
```bash
# Check what's using the port
sudo netstat -tlnp | grep :5000

# Change port in environment
export PORT=5001
./start-edgequark.sh
```

### Debug Mode
```bash
# Start in debug mode
FLASK_ENV=development ./start-edgequark.sh

# Enable verbose logging
LOG_LEVEL=DEBUG ./start-edgequark.sh
```

## 📈 Performance

### Optimization Tips
- Adjust worker count based on CPU cores
- Monitor memory usage and adjust accordingly
- Use reverse proxy (nginx) for static files
- Implement caching for frequent requests
- Regular log rotation and cleanup

### Scaling
```bash
# Increase workers
export WORKERS=8
./start-edgequark.sh restart

# Adjust timeouts
export TIMEOUT=180
./start-edgequark.sh restart
```

## 🤝 Support

### Getting Help
- Check logs: `./start-edgequark.sh logs`
- Run health check: `curl http://localhost:5000/api/health`
- Test API: `./test-api.sh`
- Review configuration: `cat .env`

### Useful Commands
```bash
# Full system check
./start-edgequark.sh check

# Reset and reinstall
./setup.sh full

# Backup configuration
tar -czf edgequark-backup.tar.gz *.sh *.py templates/ static/ *.conf *.service
```

## 📝 License

This EdgeQuark Document Fraud Detection Platform is provided as a production-ready implementation for document analysis and fraud detection using AI technology.

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-19  
**Platform**: Linux x86_64