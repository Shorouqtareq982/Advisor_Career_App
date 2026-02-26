import asyncio
from typing import Literal, Optional, List, Dict, Union
from uuid import UUID
import cloudinary
import cloudinary.uploader
import cloudinary.api
from fastapi import Depends, UploadFile
from starlette.datastructures import UploadFile as StarletteUploadFile
from cloudinary.exceptions import Error as CloudinaryError
from shared.helpers.file_validation import FileValidator
from core.config import Settings, get_settings
from shared.helpers.loggers import get_logger

logger = get_logger(__name__)


#TODO: fix public_id generation to avoid collisions and ensure uniqueness (e.g. include timestamp or UUID) and also consider using folder structure based on user_id and fileType for better organization
#TODO: test all methods
#Note: go to cloudinary setting → security → check "Allow delivery of PDF and ZIP files" option for CV file uploads be publicly accessible
class CloudinaryStorageProvider:
    def __init__(self):
        pass

    # -----------------------------------
    # Upload from FastAPI UploadFile
    # -----------------------------------
    async def upload_file(
        self,
        file: Union[UploadFile, str],
        public_id: Optional[str] = None,
        user_id: Optional[UUID] = None,
        fileType: Optional[str] = None
    ) -> Dict:
        """
        Upload a file to Cloudinary.
        
        Args:
            file: UploadFile object or base64 string/file path
            public_id: Custom public ID for the file
            user_id: User ID for folder organization
            fileType: File type (cv, profile_picture, etc)
            
        Returns:
            Cloudinary upload response
            
        Raises:
            Exception: If upload fails
        """
        try:
            if isinstance(file, (UploadFile, StarletteUploadFile)):
                file.file.seek(0)
                file_bytes = file.file
            else:
                file_bytes = file

            asset_folder = f"user_{user_id}" if user_id else "general"
            if fileType:
                asset_folder += f"/{fileType}"

            resource_type = self._get_resource_type(file)

            def _upload():
                return cloudinary.uploader.upload(
                    file_bytes,
                    asset_folder=asset_folder,
                    public_id=public_id,
                    use_filename=True,
                    resource_type=resource_type,
                    access_control=[{"access_type": "anonymous"}]
                )

            result = await asyncio.to_thread(_upload)
            logger.debug(f"File uploaded successfully to Cloudinary for user: {user_id}")
            return result
        
        except CloudinaryError as e:
            logger.error(f"Cloudinary upload failed for user {user_id}: {str(e)}", exc_info=True)
            raise Exception(f"Cloudinary upload failed: {str(e)}") from e
        except Exception as e:
            logger.error(f"Unexpected error during Cloudinary upload for user {user_id}: {str(e)}", exc_info=True)
            raise Exception(f"File upload failed: {str(e)}") from e
    
    def _get_resource_type(self, file: Union[UploadFile, str]) -> str:
        """Determine resource type based on file extension."""
        try:
            if isinstance(file, (UploadFile, StarletteUploadFile)):
                file_extension = FileValidator.get_extension(file)
            else:
                file_extension = FileValidator.get_extension_from_string(file)

            image_extensions = {"jpg", "jpeg", "png", "gif", "bmp", "tiff"}
            video_extensions = {"mp4", "avi", "mov", "wmv", "flv"}
            raw_extensions = {"pdf", "doc", "docx", "txt"}

            ext = file_extension.lower()
            if ext in image_extensions:
                return "image"
            elif ext in video_extensions:
                return "video"
            elif ext in raw_extensions:
                return "raw"
            else:
                return "auto"
        except Exception as e:
            logger.warning(f"Could not determine resource type, defaulting to 'auto': {str(e)}")
            return "auto"

    # -----------------------------
    # Delete file
    # -----------------------------
    async def delete_file(self, public_id: str, prefix: Optional[str] = None) -> bool:
        """
        Delete a single file from Cloudinary.
        
        Args:
            public_id: Public ID of the file
            prefix: Optional prefix to prepend to public_id
            
        Returns:
            True if deletion successful, False otherwise
            
        Raises:
            Exception: If deletion fails
        """
        try:
            if prefix:
                public_id = f"{prefix}/{public_id}"
            
            def _delete():
                return cloudinary.uploader.destroy(
                    public_id,
                    resource_type="auto"
                )

            result = await asyncio.to_thread(_delete)
            logger.debug(f"File deleted from Cloudinary: {public_id}")
            return result.get("result") == "ok"
        except CloudinaryError as e:
            logger.error(f"Cloudinary delete failed for public_id {public_id}: {str(e)}", exc_info=True)
            raise Exception(f"Cloudinary delete failed: {str(e)}") from e
        except Exception as e:
            logger.error(f"Unexpected error deleting file {public_id}: {str(e)}", exc_info=True)
            raise Exception(f"File deletion failed: {str(e)}") from e
    
    # -----------------------------
    # Delete files bulk
    # -----------------------------
    async def delete_all_user_files_bulk(self, user_id: UUID, fileType: str) -> Dict:
        """
        Delete all files for a user of a specific type.
        
        Args:
            user_id: User ID
            fileType: File type (cv, profile_picture, etc)
            
        Returns:
            Cloudinary API response
            
        Raises:
            Exception: If bulk deletion fails
        """
        try:
            prefix = f"user_{user_id}/{fileType}"

            def _delete():
                return cloudinary.api.delete_resources_by_prefix(prefix)

            result = await asyncio.to_thread(_delete)
            logger.debug(f"Files deleted from Cloudinary for user {user_id}, type: {fileType}")
            return result
        except CloudinaryError as e:
            logger.error(f"Cloudinary bulk delete failed for prefix {prefix}: {str(e)}", exc_info=True)
            raise Exception(f"Cloudinary bulk delete failed: {str(e)}") from e
        except Exception as e:
            logger.error(f"Unexpected error during bulk delete for user {user_id}: {str(e)}", exc_info=True)
            raise Exception(f"Bulk file deletion failed: {str(e)}") from e

    # -----------------------------
    # List files
    # -----------------------------
    async def list_files(
        self,
        user_id: Optional[UUID] = None,
        fileType: Optional[str] = None
    ) -> List[Dict]:
        """
        List files in Cloudinary for a user.
        
        Args:
            user_id: Optional user ID
            fileType: Optional file type filter
            
        Returns:
            List of file resources
            
        Raises:
            Exception: If listing fails
        """
        try:
            def _list():
                asset_folder = f"user_{user_id}" if user_id else "general"
                if fileType:
                    asset_folder += f"/{fileType}"
                return cloudinary.api.resources_by_asset_folder(
                    asset_folder=asset_folder,
                    max_results=100
                )

            response = await asyncio.to_thread(_list)
            result = response.get("resources", [])
            logger.debug(f"Listed {len(result)} files from Cloudinary for user: {user_id}")
            return result
        except CloudinaryError as e:
            logger.error(f"Cloudinary list files failed for user {user_id}: {str(e)}", exc_info=True)
            raise Exception(f"Failed to list files: {str(e)}") from e
        except Exception as e:
            logger.error(f"Unexpected error listing files for user {user_id}: {str(e)}", exc_info=True)
            raise Exception(f"File listing failed: {str(e)}") from e

    # -----------------------------
    # Get metadata
    # -----------------------------
    async def get_file_metadata(self, public_id: str) -> Dict:
        """
        Get metadata for a file from Cloudinary.
        
        Args:
            public_id: Public ID of the file
            
        Returns:
            File metadata
            
        Raises:
            Exception: If retrieval fails
        """
        try:
            def _get():
                return cloudinary.api.resource(
                    public_id,
                    resource_type="auto"
                )
            
            metadata = await asyncio.to_thread(_get)
            logger.debug(f"Retrieved metadata for file: {public_id}")
            return metadata
        except CloudinaryError as e:
            logger.error(f"Cloudinary get metadata failed for {public_id}: {str(e)}", exc_info=True)
            raise Exception(f"Failed to retrieve file metadata: {str(e)}") from e
        except Exception as e:
            logger.error(f"Unexpected error retrieving metadata for {public_id}: {str(e)}", exc_info=True)
            raise Exception(f"Metadata retrieval failed: {str(e)}") from e

    # -----------------------------
    # Check if exists
    # -----------------------------
    async def file_exists(self, public_id: str) -> bool:
        """
        Check if a file exists in Cloudinary.
        
        Args:
            public_id: Public ID of the file
            
        Returns:
            True if file exists, False otherwise
        """
        try:
            await self.get_file_metadata(public_id)
            return True
        except Exception:
            logger.debug(f"File does not exist: {public_id}")
            return False 
    

def configure_cloudinary(settings: Settings = None):
    """Configure Cloudinary with API credentials."""
    if settings is None:
        settings = get_settings()
    try:
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
            secure=True
        )
        logger.debug("Cloudinary configured successfully")
    except Exception as e:
        logger.error(f"Failed to configure Cloudinary: {str(e)}", exc_info=True)
        raise Exception(f"Cloudinary configuration failed: {str(e)}") from e
