import os
import re
from typing import Iterable, Optional, Tuple
from fastapi import UploadFile


class FileValidator:
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB default

    DEFAULT_ALLOWED_EXTENSIONS = {"pdf", "doc", "docx", "png", "jpg", "jpeg", "txt"}

    DEFAULT_ALLOWED_CONTENT_TYPES = {
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "image/png",
        "image/jpeg",
        "text/plain",
    }

    # =========================
    # Public Validation Methods
    # =========================

    @staticmethod
    def validate_file(
        file: UploadFile,
        max_size: Optional[int] = None,
        allowed_extensions: Optional[Iterable[str]] = None,
        allowed_content_types: Optional[Iterable[str]] = None,
        validate_name: bool = False,
    ) -> Tuple[bool, Optional[str]]:
        """
        Validate uploaded file.
        Returns:
            (True, None) if valid
            (False, error_message) if invalid
        """

        if not file:
            return False, "No file provided."

        max_size = max_size or FileValidator.MAX_FILE_SIZE
        allowed_extensions = set(allowed_extensions or FileValidator.DEFAULT_ALLOWED_EXTENSIONS)
        allowed_content_types = set(
            allowed_content_types or FileValidator.DEFAULT_ALLOWED_CONTENT_TYPES
        )

        # Validate filename
        if validate_name:
            if not file.filename:
                return False, "File must have a name."

            is_valid, error = FileValidator.validate_filename(file.filename)
            if not is_valid:
                return False, error

        # Validate extension
        extension = FileValidator.get_extension_from_name(file.filename)
        if extension not in allowed_extensions:
            return False, f"Invalid file extension. Allowed: {allowed_extensions}"

        # Validate content type
        if file.content_type not in allowed_content_types:
            return False, f"Invalid content type. Allowed: {allowed_content_types}"

        # Validate file size
        if hasattr(file, "size") and file.size and file.size > max_size:
            return False, f"File too large. Max allowed size is {max_size // (1024 * 1024)}MB."

        return True, None

    @staticmethod
    def validate_cv_file(file: UploadFile) -> Tuple[bool, Optional[str]]:
        return FileValidator.validate_file(
            file,
            max_size=10 * 1024 * 1024,
            allowed_extensions={"pdf", "docx", "txt"},
            allowed_content_types={
                "application/pdf",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                "text/plain",
            },
        )

    # =========================
    # Filename Validation
    # =========================

    @staticmethod
    def validate_filename(filename: str) -> Tuple[bool, Optional[str]]:
        """
        Prevent path traversal & unsafe names.
        """

        if ".." in filename or filename.startswith("/"):
            return False, "Invalid file name."

        if not re.match(r"^[\w,\s-]+\.[A-Za-z]{2,5}$", filename):
            return False, "Unsafe file name."

        return True, None

    @staticmethod
    def clean_filename(orig_file_name: str, remove_extension: bool = False) -> str:
        cleaned_file_name = re.sub(r"[^\w.]", "", orig_file_name.strip())
        cleaned_file_name = cleaned_file_name.replace(" ", "_")
        if remove_extension:
            cleaned_file_name = os.path.splitext(cleaned_file_name)[0]
        return cleaned_file_name

    # =========================
    # Helpers
    # =========================

    @staticmethod
    def get_extension_from_name(filename: str) -> str:
        return os.path.splitext(filename)[1].lower().replace(".", "")

    @staticmethod
    def get_extension(file: UploadFile) -> str:
        return FileValidator.get_extension_from_name(file.filename)
    
    @staticmethod
    def get_extension_from_string(file_str: str) -> str:
        # Try to extract extension from base64 string
        if file_str.startswith("data:"):
            try:
                header = file_str.split(";")[0]
                ext = header.split("/")[1]
                return ext
            except Exception:
                pass

        #extract extension from file path if it's a local file path
        if "/" in file_str:
            ext = file_str.split("/")[-1].split(".")[-1]
            if ext:
                return ext
            
        return FileValidator.get_extension_from_name(file_str)
