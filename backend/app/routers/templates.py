from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

from app.database import get_db
from app.models import DocumentTemplate, User
from app.main import get_current_user

router = APIRouter(
    prefix="/api/templates",
    tags=["templates"]
)

class DocumentTemplateBase(BaseModel):
    name: str
    document_type: str
    is_default: bool = False
    paper_size: str = "A4"
    orientation: str = "Portrait"
    margin_top: float = 20.0
    margin_bottom: float = 20.0
    margin_left: float = 20.0
    margin_right: float = 20.0
    template_type: str = "visual"
    background_file_url: Optional[str] = None
    visual_config: Optional[str] = None

class DocumentTemplateCreate(DocumentTemplateBase):
    pass

class DocumentTemplateUpdate(DocumentTemplateBase):
    pass

class DocumentTemplateOut(DocumentTemplateBase):
    id: int
    agency_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

@router.get("/", response_model=List[DocumentTemplateOut])
def get_templates(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    templates = db.query(DocumentTemplate).filter(DocumentTemplate.agency_id == current_user.agency_id).all()
    return templates

@router.post("/", response_model=DocumentTemplateOut)
def create_template(template: DocumentTemplateCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # If setting to default, unset others for this document type
    if template.is_default:
        db.query(DocumentTemplate).filter(
            DocumentTemplate.agency_id == current_user.agency_id,
            DocumentTemplate.document_type == template.document_type
        ).update({"is_default": False})
        
    db_template = DocumentTemplate(
        agency_id=current_user.agency_id,
        **template.dict()
    )
    db.add(db_template)
    db.commit()
    db.refresh(db_template)
    return db_template

@router.get("/{template_id}", response_model=DocumentTemplateOut)
def get_template(template_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    template = db.query(DocumentTemplate).filter(
        DocumentTemplate.id == template_id,
        DocumentTemplate.agency_id == current_user.agency_id
    ).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    return template

@router.put("/{template_id}", response_model=DocumentTemplateOut)
def update_template(template_id: int, template: DocumentTemplateUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_template = db.query(DocumentTemplate).filter(
        DocumentTemplate.id == template_id,
        DocumentTemplate.agency_id == current_user.agency_id
    ).first()
    
    if not db_template:
        raise HTTPException(status_code=404, detail="Template not found")
        
    if template.is_default and not db_template.is_default:
        db.query(DocumentTemplate).filter(
            DocumentTemplate.agency_id == current_user.agency_id,
            DocumentTemplate.document_type == template.document_type,
            DocumentTemplate.id != template_id
        ).update({"is_default": False})
        
    for key, value in template.dict().items():
        setattr(db_template, key, value)
        
    db.commit()
    db.refresh(db_template)
    return db_template

@router.delete("/{template_id}")
def delete_template(template_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_template = db.query(DocumentTemplate).filter(
        DocumentTemplate.id == template_id,
        DocumentTemplate.agency_id == current_user.agency_id
    ).first()
    
    if not db_template:
        raise HTTPException(status_code=404, detail="Template not found")
        
    db.delete(db_template)
    db.commit()
    return {"message": "Template deleted successfully"}

import os
import uuid
from fastapi import UploadFile, File

@router.post("/upload-background")
async def upload_background(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    # Save the file to documents/templates
    upload_dir = "documents/templates"
    os.makedirs(upload_dir, exist_ok=True)
    
    ext = os.path.splitext(file.filename)[1].lower()
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.join(upload_dir, filename)
    
    with open(filepath, "wb") as buffer:
        content = await file.read()
        buffer.write(content)

    preview_url = None
    if ext == ".pdf":
        try:
            import fitz
            doc = fitz.open(filepath)
            page = doc.load_page(0)
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
            preview_filename = f"{uuid.uuid4()}.png"
            preview_filepath = os.path.join(upload_dir, preview_filename)
            pix.save(preview_filepath)
            preview_url = f"http://127.0.0.1:8000/{preview_filepath.replace(os.sep, '/')}"
        except Exception as e:
            print(f"Error generating PDF preview: {e}")

    url = f"http://127.0.0.1:8000/{filepath.replace(os.sep, '/')}"
    if preview_url is None:
        preview_url = url
        
    return {"url": url, "preview_url": preview_url}

