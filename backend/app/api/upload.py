from fastapi import APIRouter, UploadFile, File, HTTPException, status
from typing import Optional

from shared.providers.storage.azure_blob_storage import get_azure_storage_provider
from shared.helpers.loggers import get_logger

logger = get_logger(__name__)
router = APIRouter(prefix="/upload", tags=["File Upload"])


@router.post("/file")
async def upload_file(
    file: UploadFile = File(...),
    folder: Optional[str] = "uploads"
):
    try:
        # Get storage provider
        storage = get_azure_storage_provider()
        
        # Upload file
        result = storage.upload_file(
            file=file.file,
            filename=file.filename,
            folder=folder,
            content_type=file.content_type
        )
        
        logger.info(f"File uploaded successfully: {file.filename}")
        
        return {
            "success": True,
            "message": f"File '{file.filename}' uploaded successfully",
            "data": {
                "blob_name": result["blob_name"],
                "url": result["url"],
                "original_filename": file.filename,
                "content_type": result["content_type"],
                "uploaded_at": result["uploaded_at"]
            }
        }
        
    except Exception as e:
        logger.error(f"Error uploading file: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file: {str(e)}"
        )

@router.get("/file/{blob_name:path}")
async def get_file(blob_name: str):
    try:
        storage = get_azure_storage_provider()
        file_info = storage.get_file(blob_name)
        
        if not file_info:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found"
            )
        
        return {
            "success": True,
            "file": file_info
        }
        
    except Exception as e:
        logger.error(f"Error retrieving file: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve file: {str(e)}"
        )

@router.get("/files")
async def list_files(folder: str = "uploads", limit: Optional[int] = 50):
    try:
        storage = get_azure_storage_provider()
        files = storage.list_files(folder=folder, limit=limit)
        
        return {
            "success": True,
            "count": len(files),
            "files": files
        }
        
    except Exception as e:
        logger.error(f"Error listing files: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list files: {str(e)}"
        )


@router.delete("/file/{blob_name:path}")
async def delete_file(blob_name: str):
    try:
        storage = get_azure_storage_provider()
        success = storage.delete_file(blob_name)
        
        if success:
            return {
                "success": True,
                "message": f"File '{blob_name}' deleted successfully"
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found"
            )
            
    except Exception as e:
        logger.error(f"Error deleting file: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete file: {str(e)}"
        )
