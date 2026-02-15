from fastapi import APIRouter, UploadFile, File, HTTPException, status, Query
from typing import Optional, List

from shared.providers.storage.cloudinary import get_cloudinary_provider
from shared.helpers.loggers import get_logger

logger = get_logger(__name__)
router = APIRouter(prefix="/cloudinary", tags=["Cloudinary File Management"])


@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    folder: Optional[str] = Query("uploads", description="Folder path in Cloudinary"),
    resource_type: Optional[str] = Query("auto", description="Resource type: image, video, raw, auto"),
    tags: Optional[str] = Query(None, description="Comma-separated tags")):
    try:
        storage = get_cloudinary_provider()
        
        # Parse tags if provided
        tag_list = [tag.strip() for tag in tags.split(",")] if tags else None
        
        # Upload file
        result = storage.upload_file(
            file=file.file,
            filename=file.filename,
            folder=folder,
            resource_type=resource_type,
            tags=tag_list
        )
        
        logger.info(f"File uploaded to Cloudinary: {file.filename}")
        
        return {
            "success": True,
            "message": f"File '{file.filename}' uploaded successfully",
            "data": result
        }
        
    except Exception as e:
        logger.error(f"Error uploading file to Cloudinary: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file: {str(e)}"
        )


@router.get("/file/{public_id:path}")
async def get_file_info(
    public_id: str,
    resource_type: Optional[str] = Query("image", description="Resource type: image, video, raw")):
    try:
        storage = get_cloudinary_provider()
        file_info = storage.get_file_info(public_id, resource_type=resource_type)
        
        if not file_info:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"File not found: {public_id}"
            )
        
        return {
            "success": True,
            "data": file_info
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting file info: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get file info: {str(e)}"
        )


@router.get("/files")
async def list_files(
    folder: Optional[str] = Query("", description="Folder path to list"),
    resource_type: Optional[str] = Query("image", description="Resource type: image, video, raw"),
    max_results: Optional[int] = Query(50, ge=1, le=500, description="Maximum results"),
    next_cursor: Optional[str] = Query(None, description="Pagination cursor")):
    try:
        storage = get_cloudinary_provider()
        result = storage.list_files(
            folder=folder,
            resource_type=resource_type,
            max_results=max_results,
            next_cursor=next_cursor
        )
        
        return {
            "success": True,
            "data": result
        }
        
    except Exception as e:
        logger.error(f"Error listing files: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list files: {str(e)}"
        )

@router.delete("/file/{public_id:path}")
async def delete_file(
    public_id: str,
    resource_type: Optional[str] = Query("image", description="Resource type: image, video, raw"),
    invalidate: Optional[bool] = Query(True, description="Invalidate CDN cache")):
    try:
        storage = get_cloudinary_provider()
        success = storage.delete_file(
            public_id=public_id,
            resource_type=resource_type,
            invalidate=invalidate
        )
        
        if success:
            logger.info(f"File deleted from Cloudinary: {public_id}")
            return {
                "success": True,
                "message": f"File '{public_id}' deleted successfully"
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found or already deleted"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting file: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete file: {str(e)}"
        )


@router.get("/download/{public_id:path}")
async def get_download_url(
    public_id: str,
    resource_type: Optional[str] = Query("image", description="Resource type: image, video, raw")):
    try:
        storage = get_cloudinary_provider()
        url = storage.download_file(public_id, resource_type=resource_type)
        
        return {
            "success": True,
            "url": url,
            "public_id": public_id
        }
        
    except Exception as e:
        logger.error(f"Error generating download URL: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate download URL: {str(e)}"
        )

@router.get("/search")
async def search_files(
    query: str = Query(..., description="Search expression (e.g., 'folder:uploads AND tags:profile')"),
    max_results: Optional[int] = Query(50, ge=1, le=500, description="Maximum results"),
    next_cursor: Optional[str] = Query(None, description="Pagination cursor")
):
    try:
        storage = get_cloudinary_provider()
        result = storage.search_files(
            expression=query,
            max_results=max_results,
            next_cursor=next_cursor
        )
        
        return {
            "success": True,
            "data": result
        }
        
    except Exception as e:
        logger.error(f"Error searching files: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to search files: {str(e)}"
        )
