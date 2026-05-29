"""
sheka School Management System
Main Application Entry Point
"""

from app import create_app
import os
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

if __name__ == '__main__':
    # Create Flask application
    app = create_app()
    
    # Configuration
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting sheka School Management System on {host}:{port}")
    
    # Run the application
    app.run(host=host, port=port, debug=debug)
