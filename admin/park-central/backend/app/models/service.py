from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid

from app.database import Base


class Service(Base):
    """Service model representing a catalog item/service for a machine."""
    
    __tablename__ = "services"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    machine_id = Column(UUID(as_uuid=True), ForeignKey("machines.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(255), nullable=False)
    price = Column(Numeric(10, 2), nullable=False)
    status = Column(String(50), nullable=False, default="active")  # active, inactive
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return f"<Service {self.name} - ₹{self.price}>"
