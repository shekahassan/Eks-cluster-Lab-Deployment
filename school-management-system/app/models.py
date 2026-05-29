"""
sheka School Management System
Database Models
"""

from app import db
from datetime import datetime

class Student(db.Model):
    """Student Model"""
    __tablename__ = 'students'
    
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.String(20), unique=True, nullable=False, index=True)
    first_name = db.Column(db.String(100), nullable=False)
    last_name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    phone = db.Column(db.String(20))
    date_of_birth = db.Column(db.Date)
    enrollment_date = db.Column(db.DateTime, default=datetime.utcnow)
    class_id = db.Column(db.Integer, db.ForeignKey('classes.id'))
    status = db.Column(db.String(20), default='active')  # active, inactive, graduated
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'student_id': self.student_id,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'email': self.email,
            'phone': self.phone,
            'date_of_birth': self.date_of_birth.isoformat() if self.date_of_birth else None,
            'enrollment_date': self.enrollment_date.isoformat(),
            'class_id': self.class_id,
            'status': self.status
        }

class Teacher(db.Model):
    """Teacher Model"""
    __tablename__ = 'teachers'
    
    id = db.Column(db.Integer, primary_key=True)
    teacher_id = db.Column(db.String(20), unique=True, nullable=False, index=True)
    first_name = db.Column(db.String(100), nullable=False)
    last_name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    phone = db.Column(db.String(20))
    specialization = db.Column(db.String(100))
    hire_date = db.Column(db.DateTime, default=datetime.utcnow)
    status = db.Column(db.String(20), default='active')  # active, inactive, on_leave
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'teacher_id': self.teacher_id,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'email': self.email,
            'phone': self.phone,
            'specialization': self.specialization,
            'hire_date': self.hire_date.isoformat(),
            'status': self.status
        }

class Class(db.Model):
    """Class Model"""
    __tablename__ = 'classes'
    
    id = db.Column(db.Integer, primary_key=True)
    class_name = db.Column(db.String(50), nullable=False, unique=True, index=True)
    grade_level = db.Column(db.String(20), nullable=False)
    teacher_id = db.Column(db.Integer, db.ForeignKey('teachers.id'))
    max_capacity = db.Column(db.Integer, default=40)
    room_number = db.Column(db.String(20))
    status = db.Column(db.String(20), default='active')
    
    # Relationships
    students = db.relationship('Student', backref='class_rel', lazy=True)
    teacher = db.relationship('Teacher', backref='classes')
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'class_name': self.class_name,
            'grade_level': self.grade_level,
            'teacher_id': self.teacher_id,
            'max_capacity': self.max_capacity,
            'room_number': self.room_number,
            'status': self.status,
            'student_count': len(self.students)
        }
