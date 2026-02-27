from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid

from app.database import Base


class BillConfig(Base):
    """Per-machine bill / receipt configuration."""

    __tablename__ = "bill_configs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    machine_id = Column(
        UUID(as_uuid=True),
        ForeignKey("machines.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    # Header branding
    org_name = Column(String(255), nullable=False, default="")
    tagline = Column(String(255), nullable=True)
    logo_url = Column(String(500), nullable=True)

    # Unit / location details
    unit_name = Column(String(255), nullable=True)
    territory = Column(String(255), nullable=True)
    gst_number = Column(String(50), nullable=True)
    pos_id = Column(String(50), nullable=True)

    # Tax rates (percentages, e.g. 9.0 for 9 %)
    cgst_percent = Column(Numeric(5, 2), nullable=False, default=0.00)
    sgst_percent = Column(Numeric(5, 2), nullable=False, default=0.00)

    # Footer
    footer_message = Column(String(500), nullable=True, default="Thank you. Visit again")
    website = Column(String(255), nullable=True)
    toll_free = Column(String(50), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    def __repr__(self):
        return f"<BillConfig machine_id={self.machine_id} org={self.org_name}>"
