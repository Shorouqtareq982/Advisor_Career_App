from typing import Dict, Any, Optional, BinaryIO
import cloudinary.api
import hashlib
from shared.helpers.loggers import get_logger

logger = get_logger(__name__)


def calculate_file_hash(file: BinaryIO) -> str:
    """Calculate SHA256 hash of file content for deduplication."""
    sha256_hash = hashlib.sha256()
    file.seek(0)
    
    # Read file in chunks to handle large files efficiently
    for byte_block in iter(lambda: file.read(4096), b""):
        sha256_hash.update(byte_block)
    
    file.seek(0)  # Reset file pointer
    return sha256_hash.hexdigest()[:16]  # Use first 16 chars for shorter ID


def parse_context_metadata(context: Dict[str, Any]) -> Dict[str, Any]:
    if isinstance(context, dict):
        # Check if context has nested 'custom' key
        if "custom" in context:
            return context["custom"]
        return context
    return {}


def extract_resource_metadata(resource: Dict[str, Any], include_all: bool = False) -> Dict[str, Any]:
    """Extract common metadata from a Cloudinary resource."""
    metadata = {
        "public_id": resource["public_id"],
        "url": resource["secure_url"],
        "resource_type": resource["resource_type"],
        "format": resource.get("format"),
        "bytes": resource.get("bytes"),
        "created_at": resource.get("created_at"),
        "tags": resource.get("tags", [])
    }
    
    if include_all:
        metadata.update({
            "width": resource.get("width"),
            "height": resource.get("height"),
            "version": resource.get("version"),
            "asset_id": resource.get("asset_id")
        })
    
    return metadata


def store_file_metadata(filename: str) -> Dict[str, str]:
    """Prepare metadata context for storing original filename in Cloudinary."""
    file_extension = filename.split(".")[-1] if "." in filename else ""
    
    # Cloudinary stores custom metadata in 'context' field as key=value pairs
    context = {
        "original_filename": filename,
        "file_extension": file_extension
    }
    
    logger.debug(f"Prepared metadata for {filename}: {context}")
    return context


def find_resource_type(public_id: str) -> Optional[str]:
    resource_types = ["image", "video", "raw"]
    
    for res_type in resource_types:
        try:
            cloudinary.api.resource(
                public_id,
                resource_type=res_type,
                type="private"
            )
            logger.info(f"Auto-detected resource type for {public_id}: {res_type}")
            return res_type
        except cloudinary.exceptions.NotFound:
            continue
        except Exception as e:
            logger.debug(f"Error checking {res_type} for {public_id}: {str(e)}")
            continue
    
    return None


def get_file_metadata(public_id: str, resource_type: Optional[str] = None) -> Optional[Dict[str, Any]]:
    try:
        # Auto-detect resource type if not provided
        if resource_type is None:
            resource_type = find_resource_type(public_id)
            if resource_type is None:
                logger.warning(f"File not found: {public_id}")
                return None
        
        # Retrieve resource details from Cloudinary
        resource = cloudinary.api.resource(
            public_id,
            resource_type=resource_type,
            type="private"
        )
        
        # Extract context metadata using helper
        context = resource.get("context", {})
        custom_context = parse_context_metadata(context)
        
        metadata = {
            "original_filename": custom_context.get("original_filename"),
            "file_extension": custom_context.get("file_extension"),
            "format": resource.get("format"),
            "public_id": public_id,
            "resource_type": resource_type
        }
        
        logger.debug(f"Retrieved metadata for {public_id}: {metadata}")
        return metadata
        
    except cloudinary.exceptions.NotFound:
        logger.warning(f"File not found: {public_id}")
        return None
    except Exception as e:
        logger.error(f"Error retrieving metadata for {public_id}: {str(e)}")
        return None


def get_filename_with_extension(public_id: str, resource_type: Optional[str] = None) -> str:
    try:
        metadata = get_file_metadata(public_id, resource_type)
        
        # Try to use original filename from metadata
        if metadata and metadata.get("original_filename"):
            filename = metadata["original_filename"]
            logger.info(f"Using original filename: {filename}")
            return filename
        
        # Fallback: try to use format from Cloudinary
        if metadata and metadata.get("format"):
            filename = f"{public_id.split('/')[-1]}.{metadata['format']}"
            logger.info(f"Using format from Cloudinary: {filename}")
            return filename
        
        # Last resort: return public_id as is
        filename = public_id.split("/")[-1]
        logger.warning(f"No metadata found, using public_id: {filename}")
        return filename
        
    except Exception as e:
        logger.error(f"Error getting filename: {str(e)}")
        # Return public_id as fallback
        return public_id.split("/")[-1]
