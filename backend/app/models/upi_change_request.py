from sqlalchemy import Column, String, DateTime, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid

from app.database import Base


class UpiChangeRequest(Base):
    __tablename__ = "upi_change_requests"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    machine_id = Column(UUID(as_uuid=True), ForeignKey('machines.id'), nullable=False)
    requested_by = Column(UUID(as_uuid=True), ForeignKey('users.id'), nullable=False)
    old_upi_id = Column(String(255), nullable=True)
    new_upi_id = Column(String(255), nullable=False)
    # pending | approved | rejected
    status = Column(String(20), nullable=False, default='pending')
    superadmin_note = Column(Text, nullable=True)
    resolved_by = Column(UUID(as_uuid=True), ForeignKey('users.id'), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    def __repr__(self):
        return f"<UpiChangeRequest {self.machine_id} → {self.new_upi_id} ({self.status})>"
