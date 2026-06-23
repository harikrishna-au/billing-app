from sqlalchemy import Column, String, Integer, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
import uuid

from app.database import Base


class BillCounter(Base):
    """Tracks the next bill number per machine and POSID to prevent duplicates."""

    __tablename__ = "bill_counters"
    __table_args__ = (
        UniqueConstraint("machine_id", "posid", name="uq_machine_posid"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    machine_id = Column(UUID(as_uuid=True), ForeignKey("machines.id"), nullable=False)
    posid = Column(String(100), nullable=False)  # e.g., "WSSBI-AP"
    next_number = Column(Integer, nullable=False, default=1)  # Next bill number to use

    def __repr__(self):
        return f"<BillCounter {self.posid} machine={self.machine_id} next={self.next_number}>"
