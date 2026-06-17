import pdfplumber
import docx
from fastapi import UploadFile
from typing import List, Dict, Any

# ==================== Extract Text from Files ====================

async def extract_text_from_pdf(file) -> str:
    """Extract text from PDF file"""
    text = ""
    with pdfplumber.open(file) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + "\n"
    return text


async def extract_text_from_docx(file) -> str:
    """Extract text from DOCX file"""
    doc = docx.Document(file)
    text = "\n".join([paragraph.text for paragraph in doc.paragraphs])
    return text


async def extract_text_from_txt(file: UploadFile) -> str:
    """Extract text from TXT file"""
    content = await file.read()
    return content.decode('utf-8')


async def extract_text_from_cv(cv_file: UploadFile) -> str:
    """
    Extract text from CV file
    Supported formats: PDF, DOCX, TXT
    """
    filename = cv_file.filename.lower()
    
    if filename.endswith('.pdf'):
        return await extract_text_from_pdf(cv_file.file)
    elif filename.endswith('.docx'):
        return await extract_text_from_docx(cv_file.file)
    elif filename.endswith('.txt'):
        return await extract_text_from_txt(cv_file)
    else:
        raise ValueError(
            f"Unsupported file type: {cv_file.filename}. "
            "Please upload PDF, DOCX, or TXT files only."
        )


# ==================== Text Cleaning ====================

def clean_cv_text(text: str, max_length: int = 10000) -> str:
    """
    Clean CV text before sending to LLM
    - Remove extra whitespace
    - Limit length for API limits
    """
    # Remove extra spaces and line breaks
    cleaned = " ".join(text.split())
    
    # Limit length (Gemini/GPT have token limits)
    if len(cleaned) > max_length:
        cleaned = cleaned[:max_length]
    
    return cleaned