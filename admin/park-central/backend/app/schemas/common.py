from pydantic import BaseModel
from typing import Generic, TypeVar, Optional, Any

DataT = TypeVar('DataT')


class SuccessResponse(BaseModel, Generic[DataT]):
    """Generic success response wrapper."""
    success: bool = True
    data: DataT


class ErrorDetail(BaseModel):
    """Error detail schema."""
    code: str
    message: str
    details: Optional[Any] = None


class ErrorResponse(BaseModel):
    """Error response schema."""
    success: bool = False
    error: ErrorDetail


class MessageResponse(BaseModel):
    """Simple message response."""
    success: bool = True
    message: str
