"""Models for systemd unit enablement."""
from typing import List
from pydantic import BaseModel, Field


class SystemdModel(BaseModel):
    """Systemd services and sockets to enable."""
    enable_units: List[str] = Field(default_factory=list, description="Services/timers to enable")
    enable_sockets: List[str] = Field(default_factory=list, description="Sockets to enable")
