"""
sheka School Management System
API Routes/Blueprints
"""

from flask import Blueprint, jsonify, request, render_template
from app import db
from app.models import Student, Teacher, Class
import os
from datetime import datetime

# Create blueprints
main_bp = Blueprint('main', __name__)
student_bp = Blueprint('students', __name__)
teacher_bp = Blueprint('teachers', __name__)
class_bp = Blueprint('classes', __name__)

# ==================== MAIN ROUTES ====================

@main_bp.route('/')
def index():
    """Home page"""
    return jsonify({
        'message': 'Welcome to sheka School Management System',
        'version': '1.0.0',
        'status': 'running'
    }), 200

@main_bp.route('/health')
def health_check():
    """Health check endpoint for Kubernetes"""
    try:
        db.session.execute('SELECT 1')
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500

@main_bp.route('/api/stats')
def get_stats():
    """Get system statistics"""
    try:
        total_students = Student.query.count()
        total_teachers = Teacher.query.count()
        total_classes = Class.query.count()
        
        return jsonify({
            'total_students': total_students,
            'total_teachers': total_teachers,
            'total_classes': total_classes,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== STUDENT ROUTES ====================

@student_bp.route('/', methods=['GET'])
def get_all_students():
    """Get all students"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 10, type=int)
        
        pagination = Student.query.paginate(page=page, per_page=per_page)
        students = [student.to_dict() for student in pagination.items]
        
        return jsonify({
            'students': students,
            'total': pagination.total,
            'pages': pagination.pages,
            'current_page': page
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@student_bp.route('/<int:student_id>', methods=['GET'])
def get_student(student_id):
    """Get student by ID"""
    try:
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'error': 'Student not found'}), 404
        return jsonify(student.to_dict()), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@student_bp.route('/', methods=['POST'])
def create_student():
    """Create a new student"""
    try:
        data = request.get_json()
        
        # Validation
        if not data.get('first_name') or not data.get('last_name') or not data.get('email'):
            return jsonify({'error': 'Missing required fields'}), 400
        
        student = Student(
            student_id=data.get('student_id', f"STU-{datetime.now().timestamp()}"),
            first_name=data.get('first_name'),
            last_name=data.get('last_name'),
            email=data.get('email'),
            phone=data.get('phone'),
            status='active'
        )
        
        db.session.add(student)
        db.session.commit()
        
        return jsonify(student.to_dict()), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@student_bp.route('/<int:student_id>', methods=['PUT'])
def update_student(student_id):
    """Update student"""
    try:
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'error': 'Student not found'}), 404
        
        data = request.get_json()
        student.first_name = data.get('first_name', student.first_name)
        student.last_name = data.get('last_name', student.last_name)
        student.email = data.get('email', student.email)
        student.phone = data.get('phone', student.phone)
        student.status = data.get('status', student.status)
        
        db.session.commit()
        return jsonify(student.to_dict()), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@student_bp.route('/<int:student_id>', methods=['DELETE'])
def delete_student(student_id):
    """Delete student"""
    try:
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'error': 'Student not found'}), 404
        
        db.session.delete(student)
        db.session.commit()
        return jsonify({'message': 'Student deleted successfully'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==================== TEACHER ROUTES ====================

@teacher_bp.route('/', methods=['GET'])
def get_all_teachers():
    """Get all teachers"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 10, type=int)
        
        pagination = Teacher.query.paginate(page=page, per_page=per_page)
        teachers = [teacher.to_dict() for teacher in pagination.items]
        
        return jsonify({
            'teachers': teachers,
            'total': pagination.total,
            'pages': pagination.pages,
            'current_page': page
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@teacher_bp.route('/', methods=['POST'])
def create_teacher():
    """Create a new teacher"""
    try:
        data = request.get_json()
        
        if not data.get('first_name') or not data.get('last_name') or not data.get('email'):
            return jsonify({'error': 'Missing required fields'}), 400
        
        teacher = Teacher(
            teacher_id=data.get('teacher_id', f"TCH-{datetime.now().timestamp()}"),
            first_name=data.get('first_name'),
            last_name=data.get('last_name'),
            email=data.get('email'),
            phone=data.get('phone'),
            specialization=data.get('specialization'),
            status='active'
        )
        
        db.session.add(teacher)
        db.session.commit()
        
        return jsonify(teacher.to_dict()), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

# ==================== CLASS ROUTES ====================

@class_bp.route('/', methods=['GET'])
def get_all_classes():
    """Get all classes"""
    try:
        classes = Class.query.all()
        return jsonify({
            'classes': [c.to_dict() for c in classes],
            'total': len(classes)
        }), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@class_bp.route('/', methods=['POST'])
def create_class():
    """Create a new class"""
    try:
        data = request.get_json()
        
        if not data.get('class_name') or not data.get('grade_level'):
            return jsonify({'error': 'Missing required fields'}), 400
        
        class_obj = Class(
            class_name=data.get('class_name'),
            grade_level=data.get('grade_level'),
            teacher_id=data.get('teacher_id'),
            max_capacity=data.get('max_capacity', 40),
            room_number=data.get('room_number'),
            status='active'
        )
        
        db.session.add(class_obj)
        db.session.commit()
        
        return jsonify(class_obj.to_dict()), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500
