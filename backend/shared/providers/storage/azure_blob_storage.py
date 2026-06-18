from typing import Optional, BinaryIO, List
from io import BytesIO
import uuid
from datetime import datetime, timedelta
import mimetypes

from azure.storage.blob import (
    BlobServiceClient,
    BlobClient,
    ContainerClient,
    BlobSasPermissions,
    generate_blob_sas,
    ContentSettings
)
from azure.core.exceptions import AzureError, ResourceNotFoundError

from core.config import settings
from shared.helpers.loggers import get_logger


logger = get_logger(__name__)


class AzureBlobStorageProvider:
    def __init__(self, container_name: Optional[str] = None):
        try:
            self.blob_service_client = BlobServiceClient.from_connection_string(
                settings.AZURE_STORAGE_CONNECTION_STRING
            )
            self.container_name = container_name or settings.AZURE_CONTAINER_NAME
            self._ensure_container_exists()
            logger.info(f"Azure Blob Storage initialized for container: {self.container_name}")
        except Exception as e:
            logger.error(f"Failed to initialize Azure Blob Storage: {str(e)}")
            raise

    def _ensure_container_exists(self) -> None:
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            if not container_client.exists():
                container_client.create_container()
                logger.info(f"Container '{self.container_name}' created successfully")
        except Exception as e:
            logger.error(f"Error ensuring container exists: {str(e)}")
            raise

    def upload_file(
        self,
        file: BinaryIO,
        filename: str,
        folder: str = "uploads",
        content_type: Optional[str] = None,
        metadata: Optional[dict] = None
    ) -> dict:
        try:
            # Generate unique blob name
            file_extension = filename.split(".")[-1] if "." in filename else ""
            unique_filename = f"{uuid.uuid4()}.{file_extension}" if file_extension else str(uuid.uuid4())
            
            # Construct blob path
            blob_name = f"{folder}/{unique_filename}" if folder else unique_filename
            
            # Get blob client
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            
            # Determine content type
            if not content_type:
                content_type, _ = mimetypes.guess_type(filename)
                content_type = content_type or "application/octet-stream"
            
            # Prepare metadata
            upload_metadata = {
                "original_filename": filename,
                "uploaded_at": datetime.utcnow().isoformat(),
                **(metadata or {})
            }
            
            # Upload file
            file.seek(0)  # Reset file pointer
            blob_client.upload_blob(
                file,
                overwrite=True,
                content_settings=ContentSettings(content_type=content_type),
                metadata=upload_metadata
            )
            
            logger.info(f"File uploaded successfully: {blob_name}")
            
            return {
                "blob_name": blob_name,
                "url": blob_client.url,
                "container": self.container_name,
                "content_type": content_type,
                "metadata": upload_metadata,
                "uploaded_at": upload_metadata["uploaded_at"]
            }
            
        except AzureError as e:
            logger.error(f"Azure error uploading file: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Error uploading file: {str(e)}")
            raise

    def download_file(self, blob_name: str) -> BytesIO:
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            
            stream = BytesIO()
            blob_client.download_blob().readinto(stream)
            stream.seek(0)
            
            logger.info(f"File downloaded successfully: {blob_name}")
            return stream
            
        except ResourceNotFoundError:
            logger.error(f"Blob not found: {blob_name}")
            raise

    def download_to_path(self, blob_name: str, file_path: str) -> str:
        """Download a blob directly to a local file path (streaming).

        This is preferable for large files (videos) to avoid holding the full content in memory.
        """
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )

            with open(file_path, "wb") as f:
                blob_client.download_blob().readinto(f)

            logger.info(f"File downloaded successfully to path: {blob_name} -> {file_path}")
            return file_path
        except ResourceNotFoundError:
            logger.error(f"Blob not found: {blob_name}")
            raise
        except AzureError as e:
            logger.error(f"Azure error downloading file: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Error downloading file: {str(e)}")
            raise
        except AzureError as e:
            logger.error(f"Azure error downloading file: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Error downloading file: {str(e)}")
            raise

    def delete_file(self, blob_name: str) -> bool:
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            
            blob_client.delete_blob()
            logger.info(f"File deleted successfully: {blob_name}")
            return True
            
        except ResourceNotFoundError:
            logger.warning(f"Blob not found for deletion: {blob_name}")
            return False
        except AzureError as e:
            logger.error(f"Azure error deleting file: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Error deleting file: {str(e)}")
            raise

    def generate_sas_url(
        self,
        blob_name: str,
        expiry_hours: int = 1,
        permissions: str = "r"
    ) -> str:
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            
            # Generate SAS token
            sas_token = generate_blob_sas(
                account_name=blob_client.account_name,
                container_name=self.container_name,
                blob_name=blob_name,
                account_key=self.blob_service_client.credential.account_key,
                permission=BlobSasPermissions(read="r" in permissions, write="w" in permissions),
                expiry=datetime.utcnow() + timedelta(hours=expiry_hours)
            )
            
            sas_url = f"{blob_client.url}?{sas_token}"
            logger.info(f"SAS URL generated for: {blob_name}")
            return sas_url
            
        except Exception as e:
            logger.error(f"Error generating SAS URL: {str(e)}")
            raise

    def list_files(self, folder: str = "", limit: Optional[int] = None) -> List[dict]:
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            
            blobs = container_client.list_blobs(name_starts_with=folder if folder else None)
            
            files = []
            for blob in blobs:
                files.append({
                    "name": blob.name,
                    "size": blob.size,
                    "content_type": blob.content_settings.content_type if blob.content_settings else None,
                    "created_at": blob.creation_time.isoformat() if blob.creation_time else None,
                    "modified_at": blob.last_modified.isoformat() if blob.last_modified else None,
                    "metadata": blob.metadata
                })
                
                if limit and len(files) >= limit:
                    break
            
            logger.info(f"Listed {len(files)} files from folder: {folder or 'root'}")
            return files
            
        except AzureError as e:
            logger.error(f"Azure error listing files: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Error listing files: {str(e)}")
            raise

    def get_file_metadata(self, blob_name: str) -> dict:
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            
            properties = blob_client.get_blob_properties()
            
            return {
                "name": blob_name,
                "size": properties.size,
                "content_type": properties.content_settings.content_type,
                "created_at": properties.creation_time.isoformat() if properties.creation_time else None,
                "modified_at": properties.last_modified.isoformat() if properties.last_modified else None,
                "metadata": properties.metadata,
                "etag": properties.etag
            }
            
        except ResourceNotFoundError:
            logger.error(f"Blob not found: {blob_name}")
            raise
        except AzureError as e:
            logger.error(f"Azure error getting file metadata: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Error getting file metadata: {str(e)}")
            raise

    def file_exists(self, blob_name: str) -> bool:
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_name
            )
            return blob_client.exists()
            
        except Exception as e:
            logger.error(f"Error checking file existence: {str(e)}")
            return False


# Singleton instances per container
_azure_storage_providers: dict = {}


def get_azure_storage_provider(container_name: Optional[str] = None) -> AzureBlobStorageProvider:
    key = container_name or settings.AZURE_CONTAINER_NAME
    if not key:
        raise ValueError("Azure container name is not configured")

    if key not in _azure_storage_providers:
        _azure_storage_providers[key] = AzureBlobStorageProvider(container_name=key)

    return _azure_storage_providers[key]