from fastapi import APIRouter, UploadFile, File, HTTPException, status, Query, Depends
from fastapi.responses import StreamingResponse
from typing import Optional
import mimetypes

from shared.providers.storage.cloudinary import get_cloudinary_provider, CloudinaryProvider
from shared.helpers.loggers import get_logger
from shared.helpers.handlers import success_response, handle_error

logger = get_logger(__name__)
router = APIRouter(prefix="/cloudinary", tags=["Cloudinary File Management"])


# Dependency for getting storage provider
def get_storage() -> CloudinaryProvider:
    """Dependency to get Cloudinary storage provider."""
    return get_cloudinary_provider()

#-------------------- Upload ------------------- #

@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    folder: Optional[str] = Query("uploads", description="Folder path in Cloudinary"),
    tags: Optional[str] = Query(None, description="Comma-separated tags"),
    use_content_hash: Optional[bool] = Query(True, description="Use content hash to prevent duplicates (True) or allow duplicates with UUID (False)"),
    storage: CloudinaryProvider = Depends(get_storage)
):
    """
    Upload a file with automatic resource type detection.
    Cloudinary will automatically detect if the file is an image, video, or raw file.
    """
    try:
        # Parse tags if provided
        tag_list = [tag.strip() for tag in tags.split(",")] if tags else None
        
        # Upload file with auto-detection
        result = storage.upload_file(
            file=file.file,
            filename=file.filename,
            folder=folder,
            tags=tag_list,
            use_content_hash=use_content_hash
        )
        
        logger.info(f"File uploaded to Cloudinary: {file.filename} (auto-detected type: {result.get('resource_type')})")
        return success_response(
            data=result,
            message=f"File '{file.filename}' uploaded successfully as {result.get('resource_type')}"
        )
        
    except ValueError as e:
        # Handle resource type mismatch
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        handle_error(e, "upload file")

#-------------------- List files ------------------- #

@router.get("/files")
async def list_files(
    folder: Optional[str] = Query("", description="Folder path to list"),
    max_results: Optional[int] = Query(50, ge=1, le=500, description="Maximum results"),
    next_cursor: Optional[str] = Query(None, description="Pagination cursor"),
    storage: CloudinaryProvider = Depends(get_storage)
):
    try:
        # List files from all resource types (image, video, raw)
        all_files = []
        for res_type in ["image", "video", "raw"]:
            try:
                result = storage.list_files(
                    folder=folder,
                    resource_type=res_type,
                    max_results=max_results,
                    next_cursor=next_cursor
                )
                all_files.extend(result.get("files", []))
            except Exception as e:
                logger.debug(f"No files found in {res_type}: {str(e)}")
                continue
        
        result = {
            "files": all_files,
            "count": len(all_files),
            "total_count": len(all_files)
        }
        
        return success_response(data=result)
        
    except Exception as e:
        handle_error(e, "list files")

#-------------------- Download file ------------------- #

@router.get("/download/{public_id:path}")
async def download_file(
    public_id: str,
    storage: CloudinaryProvider = Depends(get_storage)
):
    """Download a file with proper filename and extension. Automatically detects file type."""
    try:
        # Get file content and original filename from Cloudinary (auto-detects type)
        file_content, filename = storage.get_file_content(public_id, resource_type=None)
        
        # Detect MIME type from filename
        mime_type, _ = mimetypes.guess_type(filename)
        if not mime_type:
            mime_type = "application/octet-stream"
        
        logger.info(f"Downloading file: {public_id} as {filename}")
        
        # Return file with proper headers so it downloads with correct extension
        return StreamingResponse(
            file_content,
            media_type=mime_type,
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"'
            }
        )
        
    except Exception as e:
        handle_error(e, "download file")

#-------------------- Delete a file ------------------- #

@router.delete("/file/{public_id:path}")
async def delete_file(
    public_id: str,
    invalidate: Optional[bool] = Query(True, description="Invalidate CDN cache"),
    storage: CloudinaryProvider = Depends(get_storage)
):
    """Delete a file. Automatically detects file type."""
    try:
        is_deleted = storage.delete_file(
            public_id=public_id,
            resource_type=None,
            invalidate=invalidate
        )
        
        if is_deleted:
            logger.info(f"File deleted from Cloudinary: {public_id}")
            return success_response(message=f"File '{public_id}' deleted successfully")
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found or already deleted"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        handle_error(e, "delete file")

#-------------------- Update a file ------------------- #

@router.put("/file/{public_id:path}")
async def update_file(
    public_id: str,
    file: Optional[UploadFile] = File(None, description="New file to replace the existing one"),
    tags: Optional[str] = Query(None, description="Comma-separated tags to replace existing tags"),
    invalidate: Optional[bool] = Query(True, description="Clear CDN cache to show updated file immediately"),
    storage: CloudinaryProvider = Depends(get_storage)
):
    """Update a file. Automatically detects file type and validates replacement matches original type."""
    try:
        # Parse tags if provided
        tag_list = [tag.strip() for tag in tags.split(",")] if tags else None
        
        # Update file (auto-detects resource type)
        result = storage.update_file(
            public_id=public_id,
            file=file.file if file else None,
            filename=file.filename if file else None,
            resource_type=None,
            tags=tag_list,
            invalidate=invalidate
        )
        
        if not result:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"File '{public_id}' not found"
            )
        
        logger.info(f"File updated in Cloudinary: {public_id}")
        return success_response(
            data=result,
            message=f"File '{public_id}' updated successfully"
        )
        
    except ValueError as e:
        # Handle resource type mismatch
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except HTTPException:
        raise
    except Exception as e:
        handle_error(e, "update file")


#-------------------- Delete a folder ------------------- #

@router.delete("/folder/{folder:path}")
async def delete_folder(
    folder: str,
    invalidate: Optional[bool] = Query(True, description="Invalidate CDN cache"),
    storage: CloudinaryProvider = Depends(get_storage)
):
    """Delete a folder and all its contents across all resource types."""
    try:
        # Delete from all resource types
        total_deleted = 0
        deleted_files = {}
        
        for res_type in ["image", "video", "raw"]:
            try:
                result = storage.delete_folder(
                    folder=folder,
                    resource_type=res_type,
                    invalidate=invalidate
                )
                total_deleted += result.get("deleted_count", 0)
                deleted_files.update(result.get("deleted_files", {}))
            except Exception as e:
                logger.debug(f"No files found in {res_type} for folder {folder}: {str(e)}")
                continue
        
        result = {
            "folder": folder,
            "deleted_count": total_deleted,
            "deleted_files": deleted_files
        }
        
        logger.info(f"Folder deleted from Cloudinary: {folder} ({result['deleted_count']} files)")
        return success_response(
            data=result,
            message=f"Folder '{folder}' and {result['deleted_count']} file(s) deleted successfully"
        )
        
    except Exception as e:
        handle_error(e, "delete folder")
