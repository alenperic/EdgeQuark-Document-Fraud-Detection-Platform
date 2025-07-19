# EdgeQuark Document Fraud Detection Platform - Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Quick Start Deployment](#quick-start-deployment)
3. [Production Deployment](#production-deployment)
4. [Configuration Management](#configuration-management)
5. [Security Hardening](#security-hardening)
6. [Monitoring and Logging](#monitoring-and-logging)
7. [Troubleshooting](#troubleshooting)
8. [Scaling and Performance](#scaling-and-performance)

## Prerequisites

### System Requirements
- **Operating System**: Linux (Ubuntu 20.04+, CentOS 8+, or similar)
- **Python**: 3.8 or higher
- **Memory**: Minimum 2GB RAM (4GB+ recommended)
- **Storage**: 10GB available space
- **CPU**: 2+ cores recommended for production

### Required Services
- **Ollama**: AI model serving platform
- **EdgeQuark Model**: Document fraud detection AI model
- **systemd**: For service management (included in most Linux distributions)

### Network Requirements
- **Port 5000**: Default application port (configurable)
- **Port 11434**: Ollama API port
- **Internet Access**: For downloading dependencies during setup

## Quick Start Deployment

### 1. Download and Setup
```bash
# Navigate to the platform directory
cd /home/alen/edgequark-platform

# Run the automated setup
./setup.sh full
```

### 2. Start the Platform
```bash
# Start immediately
./start-edgequark.sh

# Or install as system service
sudo systemctl enable edgequark
sudo systemctl start edgequark
```

### 3. Verify Installation
```bash
# Check service status
./start-edgequark.sh status

# Run API tests
./test-api.sh quick

# Check health endpoint
curl http://localhost:5000/api/health
```

## Production Deployment

### 1. Environment Preparation

#### Create Production User
```bash
# Create dedicated user for EdgeQuark
sudo useradd -r -s /bin/bash -m edgequark
sudo usermod -aG systemd-journal edgequark

# Switch to EdgeQuark user
sudo su - edgequark
```

#### Prepare Directory Structure
```bash
# Create application directory
mkdir -p /opt/edgequark
cd /opt/edgequark

# Copy platform files
cp -r /home/alen/edgequark-platform/* .
chown -R edgequark:edgequark /opt/edgequark
```

### 2. Production Configuration

#### Environment Variables
```bash
# Create production environment file
cat > /opt/edgequark/.env.production << EOF
FLASK_ENV=production
SECRET_KEY=$(openssl rand -hex 32)
PORT=5000
HOST=0.0.0.0
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=edgequark
WORKERS=4
TIMEOUT=120
MAX_CONTENT_LENGTH=16777216
LOG_LEVEL=INFO
EOF
```

#### Gunicorn Configuration
```bash
# Update Gunicorn config for production
cat > /opt/edgequark/gunicorn.conf.py << EOF
bind = "127.0.0.1:5000"
workers = 4
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 120
keepalive = 2
preload_app = True
user = "edgequark"
group = "edgequark"
accesslog = "/opt/edgequark/logs/access.log"
errorlog = "/opt/edgequark/logs/error.log"
loglevel = "info"
pidfile = "/opt/edgequark/logs/gunicorn.pid"
proc_name = "edgequark"
EOF
```

### 3. Systemd Service Installation

#### Create Production Service File
```bash
sudo cat > /etc/systemd/system/edgequark.service << EOF
[Unit]
Description=EdgeQuark Document Fraud Detection Platform
Documentation=https://github.com/yourusername/edgequark-platform
After=network.target network-online.target ollama.service
Wants=network-online.target
Requires=network.target

[Service]
Type=notify
User=edgequark
Group=edgequark
WorkingDirectory=/opt/edgequark
Environment=PATH=/opt/edgequark/edgequark-env/bin
EnvironmentFile=/opt/edgequark/.env.production
ExecStartPre=/bin/mkdir -p /opt/edgequark/logs
ExecStartPre=/bin/mkdir -p /opt/edgequark/uploads
ExecStart=/opt/edgequark/edgequark-env/bin/gunicorn --config gunicorn.conf.py app:app
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStartSec=60
TimeoutStopSec=30
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=23

# Security Settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/edgequark/logs /opt/edgequark/uploads
PrivateTmp=true
PrivateDevices=true
ProtectHostname=true
ProtectClock=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true

# Resource Limits
LimitNOFILE=65536
LimitNPROC=4096
MemoryMax=2G

[Install]
WantedBy=multi-user.target
EOF
```

#### Enable and Start Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable edgequark
sudo systemctl start edgequark
sudo systemctl status edgequark
```

### 4. Reverse Proxy Setup (Nginx)

#### Install Nginx
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx
```

#### Configure Nginx
```bash
sudo cat > /etc/nginx/sites-available/edgequark << EOF
server {
    listen 80;
    server_name your-domain.com;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # File upload size limit
    client_max_body_size 16M;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_connect_timeout 10s;
    }
    
    # Static file handling
    location /static/ {
        alias /opt/edgequark/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/edgequark /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Configuration Management

### Environment Variables

| Variable | Default | Description | Production Value |
|----------|---------|-------------|------------------|
| `FLASK_ENV` | production | Flask environment | production |
| `SECRET_KEY` | auto-generated | Flask secret key | 64-char random string |
| `PORT` | 5000 | Application port | 5000 |
| `HOST` | 0.0.0.0 | Bind address | 127.0.0.1 |
| `OLLAMA_BASE_URL` | http://localhost:11434 | Ollama API URL | http://localhost:11434 |
| `OLLAMA_MODEL` | edgequark | AI model name | edgequark |
| `WORKERS` | 4 | Gunicorn workers | CPU cores × 2 + 1 |
| `TIMEOUT` | 120 | Request timeout | 120 |
| `LOG_LEVEL` | INFO | Logging level | INFO |

### Configuration Files

#### Application Configuration
```bash
# Main environment file
/opt/edgequark/.env.production

# Gunicorn configuration
/opt/edgequark/gunicorn.conf.py

# Systemd service
/etc/systemd/system/edgequark.service

# Nginx configuration
/etc/nginx/sites-available/edgequark
```

#### Log Rotation
```bash
# Create logrotate configuration
sudo cat > /etc/logrotate.d/edgequark << EOF
/opt/edgequark/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 edgequark edgequark
    postrotate
        systemctl reload edgequark >/dev/null 2>&1 || true
    endscript
}
EOF
```

## Security Hardening

### 1. Firewall Configuration

#### UFW (Ubuntu/Debian)
```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 5000/tcp  # Block direct access
```

#### FirewallD (CentOS/RHEL)
```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 2. SSL/TLS Configuration

#### Let's Encrypt with Certbot
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Verify auto-renewal
sudo certbot renew --dry-run
```

### 3. Application Security

#### File Permissions
```bash
# Set secure permissions
sudo chown -R edgequark:edgequark /opt/edgequark
sudo chmod 750 /opt/edgequark
sudo chmod 640 /opt/edgequark/.env.production
sudo chmod 755 /opt/edgequark/*.sh
```

#### Security Headers
```nginx
# Add to Nginx configuration
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "DENY" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
```

## Monitoring and Logging

### 1. System Monitoring

#### Service Status
```bash
# Check service status
sudo systemctl status edgequark

# View recent logs
sudo journalctl -u edgequark -f

# Check resource usage
sudo systemctl show edgequark --property=MemoryCurrent,CPUUsageNSec
```

#### Application Health
```bash
# Health check endpoint
curl -f http://localhost:5000/api/health || echo "Service unhealthy"

# Monitor response time
time curl -s http://localhost:5000/api/health > /dev/null
```

### 2. Log Management

#### Log Locations
```bash
# Application logs
/opt/edgequark/logs/edgequark.log

# Access logs
/opt/edgequark/logs/access.log

# Error logs
/opt/edgequark/logs/error.log

# System logs
sudo journalctl -u edgequark
```

#### Log Analysis
```bash
# View error patterns
sudo tail -f /opt/edgequark/logs/error.log | grep ERROR

# Monitor access patterns
sudo tail -f /opt/edgequark/logs/access.log

# System resource usage
sudo journalctl -u edgequark --since "1 hour ago" | grep -i memory
```

### 3. Alerting Setup

#### Basic Monitoring Script
```bash
#!/bin/bash
# /opt/edgequark/scripts/monitor.sh

HEALTH_URL="http://localhost:5000/api/health"
LOG_FILE="/opt/edgequark/logs/monitor.log"

if ! curl -f "$HEALTH_URL" > /dev/null 2>&1; then
    echo "$(date): EdgeQuark service is down" >> "$LOG_FILE"
    # Send alert (email, Slack, etc.)
    systemctl restart edgequark
fi
```

#### Cron Job Setup
```bash
# Add to crontab
*/5 * * * * /opt/edgequark/scripts/monitor.sh
```

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service status
sudo systemctl status edgequark

# View detailed logs
sudo journalctl -u edgequark -n 50

# Check configuration
nginx -t
python3 -m py_compile /opt/edgequark/app.py
```

#### Ollama Connection Issues
```bash
# Test Ollama connectivity
curl http://localhost:11434/api/tags

# Check EdgeQuark model
curl http://localhost:11434/api/tags | grep edgequark

# Restart Ollama if needed
sudo systemctl restart ollama
```

#### Performance Issues
```bash
# Check resource usage
top -p $(pgrep -f gunicorn)

# Monitor disk space
df -h /opt/edgequark

# Check memory usage
free -m
```

#### File Upload Issues
```bash
# Check upload directory permissions
ls -la /opt/edgequark/uploads/

# Test file size limits
curl -X POST -F "file=@large_file.pdf" http://localhost:5000/api/analyze
```

### Debug Mode

#### Enable Debug Logging
```bash
# Temporarily enable debug mode
sudo systemctl edit edgequark

# Add:
[Service]
Environment=LOG_LEVEL=DEBUG
Environment=FLASK_ENV=development

sudo systemctl restart edgequark
```

#### Performance Profiling
```bash
# Enable Gunicorn access logging
echo "access_log_format = '%(h)s %(l)s %(u)s %(t)s \"%(r)s\" %(s)s %(b)s \"%(f)s\" \"%(a)s\" %(D)s'" >> gunicorn.conf.py
sudo systemctl restart edgequark
```

## Scaling and Performance

### 1. Vertical Scaling

#### CPU Optimization
```bash
# Adjust worker count based on CPU cores
WORKERS=$(nproc --all)
echo "workers = $((WORKERS * 2 + 1))" >> gunicorn.conf.py
```

#### Memory Optimization
```bash
# Monitor memory usage per worker
ps aux | grep gunicorn | awk '{sum+=$6} END {print "Total memory: " sum/1024 " MB"}'

# Adjust worker memory limits
echo "max_requests = 1000" >> gunicorn.conf.py
echo "max_requests_jitter = 100" >> gunicorn.conf.py
```

### 2. Horizontal Scaling

#### Load Balancer Configuration
```nginx
upstream edgequark_backend {
    server 127.0.0.1:5000;
    server 127.0.0.1:5001;
    server 127.0.0.1:5002;
}

server {
    location / {
        proxy_pass http://edgequark_backend;
    }
}
```

#### Multiple Instance Setup
```bash
# Create multiple service instances
for i in {1..3}; do
    sudo cp /etc/systemd/system/edgequark.service /etc/systemd/system/edgequark@$i.service
    sudo sed -i "s/PORT=5000/PORT=500$i/" /etc/systemd/system/edgequark@$i.service
done

sudo systemctl daemon-reload
sudo systemctl enable edgequark@{1,2,3}
sudo systemctl start edgequark@{1,2,3}
```

### 3. Performance Monitoring

#### Metrics Collection
```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Monitor in real-time
htop -p $(pgrep -f gunicorn | tr '\n' ',' | sed 's/,$//')
```

#### Performance Benchmarking
```bash
# Load testing with ab
ab -n 1000 -c 10 http://localhost/api/health

# File upload testing
./test-api.sh api

# Stress testing
for i in {1..100}; do
    curl -X POST -F "file=@test.png" http://localhost/api/analyze &
done
wait
```

This deployment guide provides comprehensive instructions for setting up EdgeQuark in production environments with proper security, monitoring, and scaling considerations.