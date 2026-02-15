"""
Cloudinary Storage Provider - CRUD operations for file management
"""
from typing import Optional, BinaryIO, List, Dict, Any
import cloudinary
import cloudinary.uploader
import cloudinary.api
from cloudinary.utils import cloudinary_url
from io import BytesIO
import uuid

from core.config import settings
from shared.helpers.loggers import get_logger

logger = get_logger(__name__)


class CloudinaryProvider:
    def __init__(self):
        try:
            # Configure Cloudinary with credentials
            cloudinary.config(
                cloud_name=settings.CLOUDINARY_CLOUD_NAME,
                api_key=settings.CLOUDINARY_API_KEY,
                api_secret=settings.CLOUDINARY_API_SECRET,
                secure=True
            )
            
            # Test connection
            cloudinary.api.ping()
            logger.info("Cloudinary initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Cloudinary: {str(e)}")
            raise

    def upload_file(
        self,
        file: BinaryIO,
        filename: str,
        folder: str = "uploads",
        resource_type: str = "auto",
        tags: Optional[List[str]] = None,
        transformation: Optional[dict] = None
    ) -> Dict[str, Any]:
        try:
            # Generate unique public_id
            file_extension = filename.split(".")[-1] if "." in filename else ""
            public_id = f"{folder}/{uuid.uuid4()}"
            
            # Prepare upload options
            upload_options = {
                "public_id": public_id,
                "resource_type": resource_type,
                "folder": folder,
                "overwrite": False,
                "use_filename": False,
                "unique_filename": True,
            }
            
            if tags:
                upload_options["tags"] = tags
            
            if transformation:
                upload_options["transformation"] = transformation
            
            # Upload file
            file.seek(0)  # Reset file pointer
            result = cloudinary.uploader.upload(file, **upload_options)
            
            logger.info(f"File uploaded successfully: {result['public_id']}")
            
            return {
                "public_id": result["public_id"],
                "url": result["secure_url"],
                "resource_type": result["resource_type"],
                "format": result.get("format"),
                "width": result.get("width"),
                "height": result.get("height"),
                "bytes": result.get("bytes"),
                "created_at": result.get("created_at"),
                "original_filename": filename,
                "tags": result.get("tags", []),
                "version": result.get("version"),
                "asset_id": result.get("asset_id")
            }
            
        except Exception as e:
            logger.error(f"Error uploading file to Cloudinary: {str(e)}")
            raise

    def get_file_info(self, public_id: str, resource_type: str = "image") -> Dict[str, Any]:
        try:
            result = cloudinary.api.resource(public_id, resource_type=resource_type)
            
            return {
                "public_id": result["public_id"],
                "url": result["secure_url"],
                "resource_type": result["resource_type"],
                "format": result.get("format"),
                "width": result.get("width"),
                "height": result.get("height"),
                "bytes": result.get("bytes"),
                "created_at": result.get("created_at"),
                "tags": result.get("tags", []),
                "version": result.get("version"),
                "type": result.get("type")
            }
            
        except cloudinary.exceptions.NotFound:
            logger.warning(f"File not found: {public_id}")
            return None
        except Exception as e:
            logger.error(f"Error getting file info: {str(e)}")
            raise

    def download_file(self, public_id: str, resource_type: str = "image") -> str:
        try:
            url, _ = cloudinary_url(
                public_id,
                resource_type=resource_type,
                secure=True,
                sign_url=True,
                type="private" if resource_type == "raw" else "upload"
            )
            
            logger.info(f"Download URL generated for: {public_id}")
            return url
            
        except Exception as e:
            logger.error(f"Error generating download URL: {str(e)}")
            raise

    def delete_file(
        self,
        public_id: str,
        resource_type: str = "image",
        invalidate: bool = True
    ) -> bool:
        try:
            result = cloudinary.uploader.destroy(
                public_id,
                resource_type=resource_type,
                invalidate=invalidate
            )
            
            if result.get("result") == "ok":
                logger.info(f"File deleted successfully: {public_id}")
                return True
            else:
                logger.warning(f"File deletion returned: {result.get('result')}")
                return False
                
        except Exception as e:
            logger.error(f"Error deleting file: {str(e)}")
            raise

    def list_files(
        self,
        folder: str = "",
        resource_type: str = "image",
        max_results: int = 50,
        next_cursor: Optional[str] = None
    ) -> Dict[str, Any]:
        try:
            options = {
                "resource_type": resource_type,
                "type": "upload",
                "max_results": max_results
            }
            
            if folder:
                options["prefix"] = folder
            
            if next_cursor:
                options["next_cursor"] = next_cursor
            
            result = cloudinary.api.resources(**options)
            
            files = [
                {
                    "public_id": resource["public_id"],
                    "url": resource["secure_url"],
                    "resource_type": resource["resource_type"],
                    "format": resource.get("format"),
                    "width": resource.get("width"),
                    "height": resource.get("height"),
                    "bytes": resource.get("bytes"),
                    "created_at": resource.get("created_at"),
                    "tags": resource.get("tags", [])
                }
                for resource in result.get("resources", [])
            ]
            
            logger.info(f"Listed {len(files)} files from folder: {folder or 'root'}")
            
            return {
                "files": files,
                "count": len(files),
                "next_cursor": result.get("next_cursor"),
                "total_count": result.get("total_count")
            }
            
        except Exception as e:
            logger.error(f"Error listing files: {str(e)}")
            raise

    def generate_transformation_url(
        self,
        public_id: str,
        transformation: Dict[str, Any],
        resource_type: str = "image"
    ) -> str:
        try:
            url, _ = cloudinary_url(
                public_id,
                resource_type=resource_type,
                secure=True,
                **transformation
            )
            
            logger.info(f"Transformation URL generated for: {public_id}")
            return url
            
        except Exception as e:
            logger.error(f"Error generating transformation URL: {str(e)}")
            raise

    def search_files(
        self,
        expression: str,
        max_results: int = 50,
        next_cursor: Optional[str] = None
    ) -> Dict[str, Any]:
        try:
            search_query = cloudinary.Search().expression(expression).max_results(max_results)
            
            if next_cursor:
                search_query = search_query.next_cursor(next_cursor)
            
            result = search_query.execute()
            
            files = [
                {
                    "public_id": resource["public_id"],
                    "url": resource["secure_url"],
                    "resource_type": resource["resource_type"],
                    "format": resource.get("format"),
                    "bytes": resource.get("bytes"),
                    "created_at": resource.get("created_at"),
                    "tags": resource.get("tags", [])
                }
                for resource in result.get("resources", [])
            ]
            
            return {
                "files": files,
                "count": len(files),
                "next_cursor": result.get("next_cursor"),
                "total_count": result.get("total_count")
            }
            
        except Exception as e:
            logger.error(f"Error searching files: {str(e)}")
            raise

    def test_connection(self) -> bool:
        """Test Cloudinary connection."""
        try:
            cloudinary.api.ping()
            return True
        except Exception as e:
            logger.error(f"Connection test failed: {str(e)}")
            return False


# Singleton instance
_cloudinary_provider: Optional[CloudinaryProvider] = None


def get_cloudinary_provider() -> CloudinaryProvider:
    """Get or create Cloudinary provider singleton."""
    global _cloudinary_provider
    
    if _cloudinary_provider is None:
        _cloudinary_provider = CloudinaryProvider()
    
    return _cloudinary_provider
