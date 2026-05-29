# sheka School Management System

A comprehensive school management system built with Flask and containerized with Docker.

## Overview

sheka School Management System is a full-featured web application designed to manage schools efficiently. It provides functionality for managing students, teachers, and classes with a RESTful API.

## Features

- **Student Management**: Create, read, update, and delete student records
- **Teacher Management**: Manage teacher profiles and specializations
- **Class Management**: Organize and manage school classes
- **Health Checks**: Built-in health check endpoints for Kubernetes
- **Database Support**: SQLite for development, easily configurable for production databases
- **RESTful API**: Complete API endpoints for all operations
- **Docker Ready**: Containerized application with Docker and optimized for Kubernetes

## Project Structure

```
sheka-school-management-system/
├── app/
│   ├── __init__.py              # Flask app factory
│   ├── main.py                  # Application entry point
│   ├── models.py                # Database models (Student, Teacher, Class)
│   └── routes.py                # API routes and blueprints
├── images/                      # Application assets
│   ├── sheka-logo.svg
│   ├── school-icon.svg
│   ├── student-avatar.svg
│   ├── teacher-avatar.svg
│   └── classroom-icon.svg
├── templates/                   # HTML templates (for future use)
├── static/                      # Static files (for future use)
├── Dockerfile                   # Docker image definition
├── .dockerignore                # Docker build exclusions
├── requirements.txt             # Python dependencies
├── .env.example                 # Example environment variables
└── README.md                    # This file
```

## Prerequisites

- Python 3.11+
- Docker (for containerization)
- Docker Compose (optional, for local development)

## Installation

### Local Development Setup

1. Clone or download the project:
```bash
cd sheka-school-management-system
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Set environment variables (create `.env` file):
```bash
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
FLASK_DEBUG=True
SECRET_KEY=your-secret-key-here
```

5. Run the application:
```bash
python app/main.py
```

The application will be available at `http://localhost:5000`

### Docker Setup

1. Build the Docker image:
```bash
docker build -t shekaacademy/school-management-system:v1 .
```

2. Run the container:
```bash
docker run -d \
  --name school-mgmt \
  -p 5000:5000 \
  -e FLASK_HOST=0.0.0.0 \
  -e FLASK_PORT=5000 \
  shekaacademy/school-management-system:v1
```

3. Check the application:
```bash
curl http://localhost:5000/
```

## API Endpoints

### Health & Status

- `GET /` - Welcome message
- `GET /health` - Health check endpoint
- `GET /api/stats` - System statistics

### Students

- `GET /api/students` - Get all students (paginated)
- `GET /api/students/<id>` - Get specific student
- `POST /api/students` - Create new student
- `PUT /api/students/<id>` - Update student
- `DELETE /api/students/<id>` - Delete student

**Example Request:**
```bash
curl -X POST http://localhost:5000/api/students \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "John",
    "last_name": "Doe",
    "email": "john.doe@school.com",
    "phone": "+1234567890"
  }'
```

### Teachers

- `GET /api/teachers` - Get all teachers (paginated)
- `POST /api/teachers` - Create new teacher

**Example Request:**
```bash
curl -X POST http://localhost:5000/api/teachers \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Jane",
    "last_name": "Smith",
    "email": "jane.smith@school.com",
    "specialization": "Mathematics"
  }'
```

### Classes

- `GET /api/classes` - Get all classes
- `POST /api/classes` - Create new class

**Example Request:**
```bash
curl -X POST http://localhost:5000/api/classes \
  -H "Content-Type: application/json" \
  -d '{
    "class_name": "Class A",
    "grade_level": "10",
    "max_capacity": 40,
    "room_number": "A101"
  }'
```

## Environment Variables

- `FLASK_HOST`: Application host (default: 0.0.0.0)
- `FLASK_PORT`: Application port (default: 5000)
- `FLASK_DEBUG`: Debug mode (default: False)
- `SECRET_KEY`: Flask secret key
- `DATABASE_URL`: Database connection string (default: SQLite in-memory)

## Kubernetes Deployment

Deploy to Kubernetes using the provided manifest files:

```bash
kubectl apply -f kubernetes-manifest/14-school-management-deployment.yaml
```

The health endpoint (`/health`) is automatically used by Kubernetes for:
- Liveness probes: Restarts unhealthy containers
- Readiness probes: Routes traffic to healthy pods

## Database

The application uses SQLAlchemy ORM and supports:
- **Development**: SQLite (default, file-based)
- **Production**: PostgreSQL, MySQL, or any SQLAlchemy-supported database

To use PostgreSQL:
```bash
export DATABASE_URL="postgresql://user:password@host:5432/school_db"
```

## Technologies Used

- **Framework**: Flask 3.0.0
- **ORM**: SQLAlchemy 2.0.23
- **Web Server**: Gunicorn 21.2.0
- **Container**: Docker
- **Orchestration**: Kubernetes
- **Python**: 3.11

## Development

### Adding New Features

1. Add models in `app/models.py`
2. Create routes in `app/routes.py`
3. Update `requirements.txt` if adding dependencies
4. Rebuild Docker image

### Database Migrations

For production, consider using Alembic for database migrations:

```bash
pip install alembic
alembic init migrations
```

## Troubleshooting

### Container won't start
- Check logs: `docker logs school-mgmt`
- Verify port is not in use: `lsof -i :5000`

### Database errors
- Clear SQLite file: `rm school_management.db`
- Check database permissions

### Kubernetes issues
- Check pod logs: `kubectl logs <pod-name>`
- Describe pod: `kubectl describe pod <pod-name>`

## Performance

The application runs with:
- **Workers**: 4 (configurable in Dockerfile)
- **Timeout**: 120 seconds
- **Health Check**: Every 30 seconds

## Security Notes

- Change `SECRET_KEY` in production
- Use HTTPS in production
- Implement authentication/authorization
- Validate all user inputs
- Use environment variables for sensitive data

## Contributing

Contributions are welcome! Please follow the existing code style and add tests for new features.

## License

This project is provided as-is for educational and deployment purposes.

## Support

For issues, questions, or suggestions, please refer to the project documentation or contact the development team.

---

**Version**: 1.0.0  
**Last Updated**: January 2026  
**Maintainer**: sheka Academy
