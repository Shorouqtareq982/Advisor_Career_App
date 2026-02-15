import asyncio
from typing import Literal, Optional, List, Dict, Union
from uuid import UUID
import cloudinary
import cloudinary.uploader
import cloudinary.api
from fastapi import Depends, UploadFile
from starlette.datastructures import UploadFile as StarletteUploadFile

from core.config import Settings, get_settings

#TODO: fix public_id generation to avoid collisions and ensure uniqueness (e.g. include timestamp or UUID) and also consider using folder structure based on user_id and fileType for better organization
#TODO: fix error handling and logging for all operations, especially file uploads and interactions with Cloudinary API
#TODO: test all methods
class CloudinaryStorageProvider:
    def __init__(self):
        pass

    # -----------------------------------
    # Upload from FastAPI UploadFile
    # -----------------------------------
    async def upload_file(
        self,
        file: Union[UploadFile, str], # Can be UploadFile or raw bytes (base64 string) or file path
        public_id: Optional[str] = None,
        user_id: Optional[UUID] = None,
        fileType: Optional[str] = None #cv, profile_picture, etc
    ) -> Dict:

        if isinstance(file, (UploadFile, StarletteUploadFile)):
            file.file.seek(0)
            file_bytes = file.file
        else:
            file_bytes = file


        asset_folder = f"user_{user_id}" if user_id else "general"
        if fileType:
            asset_folder += f"/{fileType}"

        def _upload():
            return cloudinary.uploader.upload(
                file_bytes,
                asset_folder=asset_folder,
                public_id=public_id,
                use_filename=True, # Use original filename as public_id if not provided
                resource_type="auto",
            )

        return await asyncio.to_thread(_upload) #sample response at https://cloudinary.com/documentation/image_upload_api_reference#upload_response
    


    # -----------------------------
    # Delete file
    # -----------------------------
    async def delete_file(self, public_id: str, prefix: Optional[str] = None) -> bool:
        if prefix:
            public_id = f"{prefix}/{public_id}"
        def _delete():
            return cloudinary.uploader.destroy(
                public_id,
                resource_type="auto"
            )

        result = await asyncio.to_thread(_delete)
        return result.get("result") == "ok"
    
    # -----------------------------
    # Delete file bulk
    # -----------------------------
    async def delete_all_user_files_bulk(self, user_id: UUID, fileType: str) -> Dict:
        prefix = f"user_{user_id}/{fileType}"

        def _delete():
            return cloudinary.api.delete_resources_by_prefix(prefix)

        result = await asyncio.to_thread(_delete)
        return result

    # -----------------------------
    # List files
    # -----------------------------
    async def list_files(
        self,
        user_id: Optional[UUID] = None,
        fileType: Optional[str] = None
    ) -> List[Dict]:
        
        def _list():
            asset_folder = f"user_{user_id}" if user_id else "general"
            if fileType:
                asset_folder += f"/{fileType}"
            return cloudinary.api.resources_by_asset_folder(
                asset_folder=asset_folder,
                max_results=100
            )

        result = await asyncio.to_thread(_list)
        return result.get("resources", [])

    # -----------------------------
    # Get metadata
    # -----------------------------
    async def get_file_metadata(self, public_id: str) -> Dict:

        def _get():
            return cloudinary.api.resource(
                public_id,
                resource_type="auto"
            )

        return await asyncio.to_thread(_get)

    # -----------------------------
    # Check if exists
    # -----------------------------
    async def file_exists(self, public_id: str) -> bool:
        try:
            await self.get_file_metadata(public_id)
            return True
        except Exception:
            return False 
    

def configure_cloudinary(settings: Settings = None):
    if settings is None:
        settings = get_settings()
    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True
    )
