# EdgeQuark Document Fraud Detection Platform - API Documentation

## Overview

The EdgeQuark API provides programmatic access to document fraud detection capabilities. The API follows RESTful principles and supports file uploads for analysis using the EdgeQuark AI model.

**Base URL**: `http://localhost:5000` (configurable)  
**API Version**: 1.0  
**Content Type**: `application/json` for responses, `multipart/form-data` for uploads

## Authentication

Currently, the API operates without authentication for ease of deployment. For production use, implement one of the following:

- **API Keys**: Add `X-API-Key` header support
- **JWT Tokens**: Bearer token authentication
- **OAuth 2.0**: For enterprise integration

## Rate Limiting

- **Default**: No rate limiting (configure as needed)
- **Recommended**: 100 requests per minute per IP
- **File Upload**: 10 uploads per minute per IP

## API Endpoints

### 1. Health Check

Check the health and status of the EdgeQuark platform and its dependencies.

**Endpoint**: `GET /api/health`

#### Request
```http
GET /api/health HTTP/1.1
Host: localhost:5000
```

#### Response
```json
{
  "status": "healthy",
  "services": {
    "ollama": "connected",
    "flask": "running"
  },
  "version": "1.0.0",
  "timestamp": "2025-01-19T22:30:00.000Z"
}
```

#### Response Codes
- `200 OK`: Service is healthy
- `503 Service Unavailable`: Service is degraded or unhealthy

#### Response Fields
| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Overall health status: `healthy`, `degraded`, `unhealthy` |
| `services.ollama` | string | Ollama connection status: `connected`, `disconnected`, `error` |
| `services.flask` | string | Flask application status: `running` |
| `version` | string | Platform version |
| `timestamp` | string | ISO 8601 timestamp |

### 2. Document Analysis

Analyze a document for fraud detection using the EdgeQuark AI model.

**Endpoint**: `POST /api/analyze`

#### Request
```http
POST /api/analyze HTTP/1.1
Host: localhost:5000
Content-Type: multipart/form-data

file: [binary data]
```

#### cURL Example
```bash
curl -X POST \
  -F "file=@document.png" \
  http://localhost:5000/api/analyze
```

#### Python Example
```python
import requests

url = "http://localhost:5000/api/analyze"
files = {"file": open("document.png", "rb")}

response = requests.post(url, files=files)
result = response.json()
```

#### JavaScript Example
```javascript
const formData = new FormData();
formData.append('file', fileInput.files[0]);

fetch('/api/analyze', {
    method: 'POST',
    body: formData
})
.then(response => response.json())
.then(data => console.log(data));
```

#### Success Response (200 OK)
```json
{
  "success": true,
  "filename": "document.png",
  "file_type": "image/png",
  "analysis": {
    "success": true,
    "analysis": "Detailed fraud analysis results...",
    "model_used": "edgequark",
    "timestamp": "2025-01-19T22:30:00.000Z"
  },
  "api_version": "1.0",
  "timestamp": "2025-01-19T22:30:00.000Z"
}
```

#### Error Responses

**No File Provided (400 Bad Request)**
```json
{
  "success": false,
  "error": "No file provided",
  "code": "NO_FILE"
}
```

**Invalid File Type (400 Bad Request)**
```json
{
  "success": false,
  "error": "Invalid file type",
  "code": "INVALID_TYPE",
  "allowed_types": ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "pdf"]
}
```

**File Too Large (413 Payload Too Large)**
```json
{
  "success": false,
  "error": "File too large (max 16MB)",
  "code": "FILE_TOO_LARGE"
}
```

**Analysis Error (500 Internal Server Error)**
```json
{
  "success": false,
  "error": "Internal server error",
  "code": "INTERNAL_ERROR",
  "details": "EdgeQuark AI service unavailable"
}
```

#### Response Fields
| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Whether the request was successful |
| `filename` | string | Original filename of uploaded document |
| `file_type` | string | MIME type of the uploaded file |
| `analysis.success` | boolean | Whether AI analysis completed successfully |
| `analysis.analysis` | string | Detailed fraud detection analysis results |
| `analysis.model_used` | string | AI model used for analysis |
| `analysis.timestamp` | string | Analysis completion timestamp |
| `api_version` | string | API version used |
| `timestamp` | string | Request completion timestamp |

### 3. Available Models

List available AI models in the Ollama instance.

**Endpoint**: `GET /api/models`

#### Request
```http
GET /api/models HTTP/1.1
Host: localhost:5000
```

#### Response
```json
{
  "success": true,
  "models": [
    {
      "name": "edgequark",
      "modified_at": "2025-01-19T20:00:00.000Z",
      "size": 4500000000
    }
  ],
  "current_model": "edgequark"
}
```

#### Response Fields
| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Whether the request was successful |
| `models` | array | List of available models from Ollama |
| `current_model` | string | Currently configured model name |

## File Upload Specifications

### Supported File Types
- **Images**: PNG, JPEG, JPG, GIF, BMP, TIFF
- **Documents**: PDF

### File Size Limits
- **Maximum Size**: 16MB per file
- **Recommended**: Under 5MB for optimal performance

### File Validation
The API performs the following validations:
1. **Extension Check**: File extension must be in allowed list
2. **MIME Type Check**: Content-Type header validation
3. **Magic Number Check**: Binary signature verification
4. **Size Check**: File size within limits

## Error Handling

### Error Response Format
All error responses follow this format:
```json
{
  "success": false,
  "error": "Human-readable error message",
  "code": "ERROR_CODE",
  "details": "Additional technical details (optional)"
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `NO_FILE` | 400 | No file provided in request |
| `EMPTY_FILENAME` | 400 | File has empty filename |
| `INVALID_TYPE` | 400 | File type not supported |
| `UNSUPPORTED_FORMAT` | 400 | File format cannot be processed |
| `FILE_TOO_LARGE` | 413 | File exceeds size limit |
| `PROCESSING_ERROR` | 500 | Error processing uploaded file |
| `INTERNAL_ERROR` | 500 | Internal server error |
| `SERVICE_ERROR` | 503 | External service unavailable |
| `API_ERROR` | 500 | Ollama API error |

## Rate Limiting (Future Implementation)

### Headers
When rate limiting is implemented, these headers will be included:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 99
X-RateLimit-Reset: 1642678800
```

### Rate Limit Response (429 Too Many Requests)
```json
{
  "success": false,
  "error": "Rate limit exceeded",
  "code": "RATE_LIMIT_EXCEEDED",
  "retry_after": 60
}
```

## WebSocket Support (Future Enhancement)

For real-time analysis updates:

**Endpoint**: `ws://localhost:5000/ws/analyze`

```javascript
const ws = new WebSocket('ws://localhost:5000/ws/analyze');

ws.onmessage = function(event) {
    const data = JSON.parse(event.data);
    if (data.type === 'progress') {
        updateProgress(data.progress);
    } else if (data.type === 'complete') {
        displayResults(data.analysis);
    }
};
```

## SDK Examples

### Python SDK
```python
import requests
from typing import Optional, Dict

class EdgeQuarkClient:
    def __init__(self, base_url: str = "http://localhost:5000"):
        self.base_url = base_url
    
    def health_check(self) -> Dict:
        """Check service health"""
        response = requests.get(f"{self.base_url}/api/health")
        return response.json()
    
    def analyze_document(self, file_path: str) -> Dict:
        """Analyze document for fraud detection"""
        with open(file_path, 'rb') as f:
            files = {'file': f}
            response = requests.post(
                f"{self.base_url}/api/analyze", 
                files=files
            )
        return response.json()
    
    def list_models(self) -> Dict:
        """List available AI models"""
        response = requests.get(f"{self.base_url}/api/models")
        return response.json()

# Usage
client = EdgeQuarkClient()
result = client.analyze_document("suspicious_document.pdf")
print(f"Fraud Risk: {result['analysis']['analysis']}")
```

### Node.js SDK
```javascript
const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

class EdgeQuarkClient {
    constructor(baseUrl = 'http://localhost:5000') {
        this.baseUrl = baseUrl;
    }
    
    async healthCheck() {
        const response = await axios.get(`${this.baseUrl}/api/health`);
        return response.data;
    }
    
    async analyzeDocument(filePath) {
        const formData = new FormData();
        formData.append('file', fs.createReadStream(filePath));
        
        const response = await axios.post(
            `${this.baseUrl}/api/analyze`,
            formData,
            { headers: formData.getHeaders() }
        );
        
        return response.data;
    }
    
    async listModels() {
        const response = await axios.get(`${this.baseUrl}/api/models`);
        return response.data;
    }
}

// Usage
const client = new EdgeQuarkClient();
client.analyzeDocument('document.png')
    .then(result => console.log(result))
    .catch(error => console.error(error));
```

### cURL Scripts

#### Health Check Script
```bash
#!/bin/bash
# health_check.sh

response=$(curl -s -w "%{http_code}" http://localhost:5000/api/health)
http_code="${response: -3}"
body="${response%???}"

if [ "$http_code" = "200" ]; then
    echo "✅ EdgeQuark is healthy"
    echo "$body" | jq '.'
else
    echo "❌ EdgeQuark is unhealthy (HTTP $http_code)"
    echo "$body"
fi
```

#### Batch Analysis Script
```bash
#!/bin/bash
# batch_analyze.sh

for file in documents/*.{png,jpg,pdf}; do
    if [ -f "$file" ]; then
        echo "Analyzing: $file"
        curl -s -X POST \
            -F "file=@$file" \
            http://localhost:5000/api/analyze | jq '.analysis.analysis'
        echo "---"
    fi
done
```

## Performance Considerations

### Optimization Tips
1. **File Size**: Keep files under 5MB for best performance
2. **Concurrent Requests**: Limit to 4 concurrent analysis requests
3. **Caching**: Implement client-side caching for repeated analyses
4. **Compression**: Use gzip compression for API responses

### Response Times
- **Health Check**: < 100ms
- **Small Images** (< 1MB): 2-5 seconds
- **Large Images** (5-16MB): 10-30 seconds
- **PDF Documents**: 5-15 seconds

### Monitoring
Use these endpoints for monitoring:
- Health checks every 30 seconds
- Response time tracking
- Error rate monitoring
- Resource usage alerts

## Testing

### API Test Suite
The platform includes a comprehensive test suite:

```bash
# Run all API tests
./test-api.sh api

# Test specific endpoints
curl http://localhost:5000/api/health
./test-api.sh health
```

### Load Testing
```bash
# Apache Bench
ab -n 100 -c 10 http://localhost:5000/api/health

# Custom load test
for i in {1..50}; do
    curl -X POST -F "file=@test.png" http://localhost:5000/api/analyze &
done
wait
```

## Future Enhancements

### Planned Features
1. **Authentication**: API key and JWT token support
2. **Rate Limiting**: Request throttling and quotas
3. **Webhooks**: Analysis completion notifications
4. **Batch Processing**: Multiple file analysis
5. **Result Caching**: Performance optimization
6. **Metrics API**: Usage and performance statistics
7. **WebSocket**: Real-time analysis updates

### API Versioning
Future versions will maintain backward compatibility:
- **v1.0**: Current version
- **v1.1**: Enhanced authentication
- **v2.0**: Batch processing and advanced features

This API documentation provides comprehensive information for integrating with the EdgeQuark Document Fraud Detection Platform.