#!/usr/bin/env python3
"""
EdgeQuark Document Fraud Detection Platform
Main Flask application with Ollama AI integration
"""

import os
import logging
import json
import uuid
from datetime import datetime
from werkzeug.utils import secure_filename
from werkzeug.exceptions import RequestEntityTooLarge
import requests
from flask import Flask, request, render_template, jsonify, redirect, url_for, flash
import base64
import magic

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'edgequark-dev-key-change-in-production')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Configuration
OLLAMA_BASE_URL = os.environ.get('OLLAMA_BASE_URL', 'http://localhost:11434')
OLLAMA_MODEL = os.environ.get('OLLAMA_MODEL', 'edgequark')
UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff', 'pdf'}

# Ensure upload directory exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/alen/edgequark-platform/logs/edgequark.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def get_file_type(file_path):
    """Detect file type using python-magic"""
    try:
        mime_type = magic.from_file(file_path, mime=True)
        return mime_type
    except Exception as e:
        logger.error(f"Error detecting file type: {e}")
        return None

def encode_image_to_base64(file_path):
    """Convert image file to base64 encoding"""
    try:
        with open(file_path, 'rb') as image_file:
            return base64.b64encode(image_file.read()).decode('utf-8')
    except Exception as e:
        logger.error(f"Error encoding image to base64: {e}")
        return None

def analyze_document_with_ollama(image_base64, filename):
    """Send document to Ollama for fraud detection analysis"""
    try:
        prompt = """You are EdgeQuark, an advanced AI specialized in document fraud detection and forensic analysis. 

Analyze this document image for potential fraud indicators. Provide a comprehensive analysis including:

1. **Document Type Identification**: Identify what type of document this appears to be
2. **Authenticity Assessment**: Rate authenticity on a scale of 1-100 (100 = authentic)
3. **Fraud Risk Level**: LOW, MEDIUM, HIGH, CRITICAL
4. **Specific Findings**: List any suspicious elements detected:
   - Text inconsistencies or alterations
   - Image manipulation signs
   - Font irregularities
   - Color or lighting anomalies
   - Pixelation or compression artifacts
   - Misaligned elements
   - Security feature analysis

5. **Technical Analysis**: Provide forensic-level details
6. **Recommendations**: Suggest next steps for verification

Format your response as structured JSON with clear sections for easy parsing and display."""

        payload = {
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "images": [image_base64],
            "stream": False,
            "options": {
                "temperature": 0.1,
                "top_p": 0.9,
                "top_k": 40
            }
        }

        logger.info(f"Sending document analysis request for file: {filename}")
        response = requests.post(
            f"{OLLAMA_BASE_URL}/api/generate",
            json=payload,
            timeout=120
        )
        
        if response.status_code == 200:
            result = response.json()
            analysis_text = result.get('response', '')
            logger.info(f"Successfully analyzed document: {filename}")
            return {
                'success': True,
                'analysis': analysis_text,
                'model_used': OLLAMA_MODEL,
                'timestamp': datetime.now().isoformat()
            }
        else:
            logger.error(f"Ollama API error: {response.status_code} - {response.text}")
            return {
                'success': False,
                'error': f"API Error: {response.status_code}",
                'details': response.text
            }
            
    except requests.exceptions.Timeout:
        logger.error("Timeout connecting to Ollama API")
        return {
            'success': False,
            'error': "Analysis timeout - please try again",
            'details': "The AI model took too long to respond"
        }
    except requests.exceptions.ConnectionError:
        logger.error("Cannot connect to Ollama API")
        return {
            'success': False,
            'error': "Cannot connect to EdgeQuark AI service",
            'details': f"Unable to reach Ollama at {OLLAMA_BASE_URL}"
        }
    except Exception as e:
        logger.error(f"Unexpected error in document analysis: {e}")
        return {
            'success': False,
            'error': "Internal analysis error",
            'details': str(e)
        }

@app.route('/')
def index():
    """Main upload interface"""
    return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    """Handle file upload and analysis"""
    try:
        if 'file' not in request.files:
            flash('No file selected', 'error')
            return redirect(request.url)
        
        file = request.files['file']
        if file.filename == '':
            flash('No file selected', 'error')
            return redirect(request.url)
        
        if file and allowed_file(file.filename):
            # Generate unique filename
            filename = secure_filename(file.filename)
            unique_filename = f"{uuid.uuid4()}_{filename}"
            file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
            
            # Save uploaded file
            file.save(file_path)
            logger.info(f"File uploaded: {filename} -> {unique_filename}")
            
            # Verify file type
            file_type = get_file_type(file_path)
            if not file_type or not file_type.startswith(('image/', 'application/pdf')):
                os.remove(file_path)
                flash('Invalid file type. Please upload an image or PDF.', 'error')
                return redirect(url_for('index'))
            
            # Convert to base64 for Ollama
            image_base64 = encode_image_to_base64(file_path)
            if not image_base64:
                os.remove(file_path)
                flash('Error processing file', 'error')
                return redirect(url_for('index'))
            
            # Analyze with EdgeQuark AI
            analysis_result = analyze_document_with_ollama(image_base64, filename)
            
            # Clean up uploaded file
            os.remove(file_path)
            
            # Pass results to template
            return render_template('results.html', 
                                 filename=filename,
                                 analysis=analysis_result,
                                 file_type=file_type)
        else:
            flash('Invalid file type. Allowed: PNG, JPG, JPEG, GIF, BMP, TIFF, PDF', 'error')
            return redirect(url_for('index'))
            
    except RequestEntityTooLarge:
        flash('File too large. Maximum size is 16MB.', 'error')
        return redirect(url_for('index'))
    except Exception as e:
        logger.error(f"Upload error: {e}")
        flash('An error occurred during upload. Please try again.', 'error')
        return redirect(url_for('index'))

@app.route('/api/analyze', methods=['POST'])
def api_analyze():
    """API endpoint for document analysis"""
    try:
        if 'file' not in request.files:
            return jsonify({
                'success': False,
                'error': 'No file provided',
                'code': 'NO_FILE'
            }), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({
                'success': False,
                'error': 'Empty filename',
                'code': 'EMPTY_FILENAME'
            }), 400
        
        if not allowed_file(file.filename):
            return jsonify({
                'success': False,
                'error': 'Invalid file type',
                'code': 'INVALID_TYPE',
                'allowed_types': list(ALLOWED_EXTENSIONS)
            }), 400
        
        # Process file
        filename = secure_filename(file.filename)
        unique_filename = f"{uuid.uuid4()}_{filename}"
        file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
        
        file.save(file_path)
        
        # Verify file type
        file_type = get_file_type(file_path)
        if not file_type or not file_type.startswith(('image/', 'application/pdf')):
            os.remove(file_path)
            return jsonify({
                'success': False,
                'error': 'Unsupported file format',
                'code': 'UNSUPPORTED_FORMAT'
            }), 400
        
        # Convert and analyze
        image_base64 = encode_image_to_base64(file_path)
        os.remove(file_path)
        
        if not image_base64:
            return jsonify({
                'success': False,
                'error': 'File processing failed',
                'code': 'PROCESSING_ERROR'
            }), 500
        
        # Analyze with EdgeQuark AI
        analysis_result = analyze_document_with_ollama(image_base64, filename)
        
        return jsonify({
            'success': True,
            'filename': filename,
            'file_type': file_type,
            'analysis': analysis_result,
            'api_version': '1.0',
            'timestamp': datetime.now().isoformat()
        })
        
    except RequestEntityTooLarge:
        return jsonify({
            'success': False,
            'error': 'File too large (max 16MB)',
            'code': 'FILE_TOO_LARGE'
        }), 413
    except Exception as e:
        logger.error(f"API analysis error: {e}")
        return jsonify({
            'success': False,
            'error': 'Internal server error',
            'code': 'INTERNAL_ERROR',
            'details': str(e)
        }), 500

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    try:
        # Test Ollama connection
        response = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=5)
        ollama_status = response.status_code == 200
        
        return jsonify({
            'status': 'healthy' if ollama_status else 'degraded',
            'services': {
                'ollama': 'connected' if ollama_status else 'disconnected',
                'flask': 'running'
            },
            'version': '1.0.0',
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        logger.error(f"Health check error: {e}")
        return jsonify({
            'status': 'unhealthy',
            'services': {
                'ollama': 'error',
                'flask': 'running'
            },
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 503

@app.route('/api/models')
def list_models():
    """List available Ollama models"""
    try:
        response = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=10)
        if response.status_code == 200:
            models = response.json()
            return jsonify({
                'success': True,
                'models': models.get('models', []),
                'current_model': OLLAMA_MODEL
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Cannot retrieve models',
                'code': 'API_ERROR'
            }), 500
    except Exception as e:
        logger.error(f"Models list error: {e}")
        return jsonify({
            'success': False,
            'error': 'Service unavailable',
            'code': 'SERVICE_ERROR'
        }), 503

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return render_template('index.html'), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'success': False,
        'error': 'Internal server error',
        'code': 'INTERNAL_ERROR'
    }), 500

if __name__ == '__main__':
    logger.info("Starting EdgeQuark Document Fraud Detection Platform")
    logger.info(f"Ollama URL: {OLLAMA_BASE_URL}")
    logger.info(f"Using model: {OLLAMA_MODEL}")
    
    app.run(
        host='0.0.0.0',
        port=int(os.environ.get('PORT', 5000)),
        debug=os.environ.get('FLASK_ENV') == 'development'
    )