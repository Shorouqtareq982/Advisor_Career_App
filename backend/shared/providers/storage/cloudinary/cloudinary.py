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
import requests

from core.config import settings
from shared.helpers.loggers import get_logger
from .helpers import (
    store_file_metadata,
    get_filename_with_extension,
    calculate_file_hash,
    extract_resource_metadata,
    find_resource_type,
    parse_context_metadata
)

logger = get_logger(__name__)

# Configure Cloudinary once at module level
cloudinary.config(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET,
    secure=True
)


class CloudinaryProvider:
    def __init__(self):
        try:
            # Test connection
            cloudinary.api.ping()
            logger.info("Cloudinary initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Cloudinary: {str(e)}")
            raise

#-------------------- Upload a file ------------------- #
    def upload_file(
        self,
        file: BinaryIO,
        filename: str,
        folder: str = "uploads",
        tags: Optional[List[str]] = None,
        transformation: Optional[dict] = None,
        use_content_hash: bool = True
    ) -> Dict[str, Any]:
        """
        Upload a file with automatic resource type detection.
        Cloudinary will automatically detect if it's an image, video, or raw file.
        """
        try:
            # Generate public_id based on content hash (prevents duplicates) or UUID
            if use_content_hash:
                # Hash-based: same content = same public_id = automatic deduplication
                public_id = calculate_file_hash(file)
                overwrite = True  # Allow overwriting if same file is uploaded again
            else:
                # UUID-based: always create new file
                public_id = str(uuid.uuid4())
                overwrite = False
            
            # Prepare metadata context to store original filename
            metadata_context = store_file_metadata(filename)
            
            # Prepare upload options with auto-detection
            upload_options = {
                "public_id": public_id,
                "resource_type": "auto",  # Auto-detect actual file type
                "folder": folder,  # Cloudinary will prepend this to public_id
                "type": "private",  # Use private type for secure storage
                "context": metadata_context,  # Store original filename in metadata
                "overwrite": overwrite,  # Overwrite if using hash-based IDs
                "invalidate": True,  # Clear CDN cache to update timestamp and serve new version
                "use_filename": False,
                "unique_filename": False,  # Don't add random chars to hash-based IDs
            }
            
            if tags:
                upload_options["tags"] = tags
            
            if transformation:
                upload_options["transformation"] = transformation
            
            # Upload file
            file.seek(0)  # Reset file pointer
            result = cloudinary.uploader.upload(file, **upload_options)
            
            detected_type = result.get("resource_type")
            logger.info(f"File uploaded successfully: {result['public_id']} (auto-detected type: {detected_type})")
            
            # Use helper to extract metadata and add original filename
            metadata = extract_resource_metadata(result, include_all=True)
            metadata["original_filename"] = filename
            
            return metadata
            
        except Exception as e:
            logger.error(f"Error uploading file to Cloudinary: {str(e)}")
            raise

#-------------------- List files ------------------- #
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
                    "type": "private",  # List files from private storage
                    "max_results": max_results
                }
                
                if folder:
                    options["prefix"] = folder
                
                if next_cursor:
                    options["next_cursor"] = next_cursor
                
                result = cloudinary.api.resources(**options)
                
                # Use helper to extract metadata for each resource
                files = [
                    {
                        **extract_resource_metadata(resource),
                        "width": resource.get("width"),
                        "height": resource.get("height")
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

#-------------------- Update a file ------------------- #
    def update_file(
        self,
        public_id: str,
        file: Optional[BinaryIO] = None,
        filename: Optional[str] = None,
        resource_type: Optional[str] = None,
        tags: Optional[List[str]] = None,
        transformation: Optional[dict] = None,
        invalidate: bool = True
    ) -> Optional[Dict[str, Any]]:
        """
        Update an existing file. Auto-detects resource type if not provided.
        When replacing file content, validates that new file type matches original.
        """
        try:
            # Auto-detect resource type if not provided
            if resource_type is None:
                resource_type = find_resource_type(public_id)
                if resource_type is None:
                    logger.warning(f"File not found for update: {public_id}")
                    return None
            
            # Verify the existing file exists and get its resource type
            try:
                existing_resource = cloudinary.api.resource(
                    public_id,
                    resource_type=resource_type,
                    type="private"
                )
                logger.info(f"Found existing file: {public_id} (resource_type={existing_resource['resource_type']})")
            except cloudinary.exceptions.NotFound:
                logger.warning(f"File not found for update: {public_id}")
                return None
            
            # If a new file is provided, replace the existing file
            if file is not None:
                upload_opts = {
                    "public_id": public_id,  
                    "resource_type": "auto", 
                    "type": "private",
                    "overwrite": True,  
                    "invalidate": invalidate,  
                    "use_filename": False,
                    "unique_filename": False,
                }
                
                # Update metadata with new filename if provided
                if filename:
                    upload_opts["context"] = store_file_metadata(filename)
                
                if tags:
                    upload_opts["tags"] = tags
                    
                if transformation:
                    upload_opts["transformation"] = transformation

                file.seek(0)
                result = cloudinary.uploader.upload(file, **upload_opts)
                detected_type = result.get("resource_type")
                original_type = existing_resource["resource_type"]
                
                if detected_type != original_type:
                    logger.error(f"Resource type mismatch! Original: {original_type}, New: {detected_type}")
                    try:
                        cloudinary.uploader.destroy(
                            public_id,
                            resource_type=detected_type,  # Delete from the wrong namespace
                            type="private",
                            invalidate=True
                        )
                        logger.info(f"Cleaned up mismatched file: {detected_type}/{public_id}")
                    except Exception as cleanup_err:
                        logger.error(f"Failed to clean up mismatched file: {str(cleanup_err)}")
                    
                    raise ValueError(
                        f"File type mismatch: Cannot replace {original_type} file with {detected_type} file. "
                        f"Original file is '{original_type}', but uploaded file is '{detected_type}'."
                    )
                
                logger.info(f"File replaced successfully: {public_id} (resource_type={detected_type})")

            # If only updating tags (no file provided)
            elif tags is not None:
                try:
                    cloudinary.uploader.replace_tag(",".join(tags), [public_id])
                    logger.info(f"Tags updated for: {public_id}")
                except Exception:
                    cloudinary.uploader.add_tag(",".join(tags), [public_id])
                    logger.info(f"Tags added for: {public_id}")
                    
                result = None
            else:
                # Nothing to update
                logger.warning(f"Update called with no changes for: {public_id}")
                result = None

            # Fetch latest resource info to return
            resource = cloudinary.api.resource(
                public_id,
                resource_type=resource_type,
                type="private"
            )
            metadata = extract_resource_metadata(resource, include_all=True)
            metadata["type"] = resource.get("type")
            
            # Get original filename from metadata if not replaced
            if not filename:
                context = resource.get("context", {})
                custom_context = parse_context_metadata(context)
                metadata["original_filename"] = custom_context.get("original_filename")
            else:
                metadata["original_filename"] = filename

            return metadata

        except cloudinary.exceptions.NotFound:
            logger.warning(f"File not found for update: {public_id}")
            return None
        except ValueError:
            raise
        except Exception as e:
            logger.error(f"Error updating file: {str(e)}")
            raise

    def download_file(self, public_id: str, resource_type: Optional[str] = None, expiration: int = 3600) -> str: 
        """
        Generate a signed download URL. Auto-detects resource type if not provided.
        """
        try:
            # Auto-detect resource type if not provided
            if resource_type is None:
                resource_type = find_resource_type(public_id)
                if resource_type is None:
                    raise FileNotFoundError(f"File not found: {public_id}")
            
            url, _ = cloudinary_url(
                public_id,
                resource_type=resource_type,
                secure=True,
                sign_url=True,  
                type="private",  
                expires_at=int(__import__('time').time()) + expiration 
            )
            
            logger.info(f"Signed URL generated for: {public_id} (type: {resource_type}, expires in {expiration}s)")
            return url
            
        except Exception as e:
            logger.error(f"Error generating download URL: {str(e)}")
            raise

    def get_file_content(self, public_id: str, resource_type: Optional[str] = None) -> tuple[BytesIO, str]:
        """
        Fetch actual file content from Cloudinary for backend processing.
        Auto-detects resource type if not provided.
        
        Returns:
            Tuple of (file_content, filename_with_extension)
        """
        try:
            # Auto-detect resource type if not provided
            if resource_type is None:
                resource_type = find_resource_type(public_id)
                if resource_type is None:
                    raise FileNotFoundError(f"File not found: {public_id}")
            
            # Get the original filename with extension from metadata
            filename = get_filename_with_extension(public_id, resource_type)
            
            # Generate download URL
            url = self.download_file(public_id, resource_type=resource_type)
            
            # Download the file content
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            
            # Return as BytesIO object along with filename
            file_content = BytesIO(response.content)
            file_content.seek(0)
            
            logger.info(f"File content fetched successfully: {public_id} as {filename} (type: {resource_type})")
            return file_content, filename
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching file content: {str(e)}")
            raise Exception(f"Failed to download file from Cloudinary: {str(e)}")
        except Exception as e:
            logger.error(f"Error getting file content: {str(e)}")
            raise

#-------------------- Delete a file ------------------- #
    def delete_file(
        self,
        public_id: str,
        resource_type: Optional[str] = None,
        invalidate: bool = True
    ) -> bool:
        """
        Delete a file. Auto-detects resource type if not provided.
        """
        try:
            # Auto-detect resource type if not provided
            if resource_type is None:
                resource_type = find_resource_type(public_id)
                if resource_type is None:
                    logger.warning(f"File not found for deletion: {public_id}")
                    return False
            
            result = cloudinary.uploader.destroy(
                public_id,
                resource_type=resource_type,
                type="private",  
                invalidate=invalidate
            )
            
            if result.get("result") == "ok":
                logger.info(f"File deleted successfully: {public_id} (type: {resource_type})")
                return True
            else:
                logger.warning(f"File deletion returned: {result.get('result')}")
                return False
                
        except Exception as e:
            logger.error(f"Error deleting file: {str(e)}")
            raise

#-------------------- Delete a folder ------------------- #
    def delete_folder(
        self,
        folder: str,
        resource_type: str = "image",
        invalidate: bool = True
    ) -> Dict[str, Any]:
        """Delete all resources in a folder and the folder itself."""
        try:
            deleted_count = 0
            
            # Delete all resources in the folder by prefix
            result = cloudinary.api.delete_resources_by_prefix(
                folder,
                resource_type=resource_type,
                type="private",  # Specify private type for bulk deletion
                invalidate=invalidate
            )
            
            deleted_count = len(result.get("deleted", {}))
            
            # Delete the folder itself (only works if folder is empty or resources were deleted)
            try:
                cloudinary.api.delete_folder(folder)
                logger.info(f"Folder deleted successfully: {folder}")
            except Exception as folder_err:
                logger.warning(f"Folder structure delete skipped: {str(folder_err)}")
            
            return {
                "folder": folder,
                "deleted_count": deleted_count,
                "deleted_files": result.get("deleted", {}),
                "partial": result.get("partial", False)
            }
                
        except Exception as e:
            logger.error(f"Error deleting folder: {str(e)}")
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
