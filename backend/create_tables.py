import os
import sys

# Ensure we can import app modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import engine
from app.models import Base, DocumentTemplate

# This will create tables for models that don't exist yet
DocumentTemplate.__table__.create(bind=engine, checkfirst=True)
print("document_templates table created successfully.")
