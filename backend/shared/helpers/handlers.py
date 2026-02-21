from typing import Any, Dict
from fastapi import HTTPException, status

from shared.helpers.loggers import get_logger

logger = get_logger(__name__)

# Helper function for standard success responses
def success_response(data: Any = None, message: str = None) -> Dict[str, Any]:
    """Create standard success response."""
    response = {"success": True}
    if message:
        response["message"] = message
    if data is not None:
        response["data"] = data
    return response


# Helper function for handling errors
def handle_error(error: Exception, operation: str, status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR):
    """Handle and log errors, raising appropriate HTTPException."""
    logger.error(f"Error {operation}: {str(error)}")
    raise HTTPException(
        status_code=status_code,
        detail=f"Failed to {operation}: {str(error)}"
    )