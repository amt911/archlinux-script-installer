"""Models for hardware acceleration configuration."""
from pydantic import BaseModel, Field


class HardwareAccelerationModel(BaseModel):
    """Hardware acceleration configuration."""
    enable: bool = Field(default=False)
    install_codecs: bool = Field(default=True)
