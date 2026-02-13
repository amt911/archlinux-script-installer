"""Models for CUPS configuration."""
from pydantic import BaseModel, Field


class CupsModel(BaseModel):
    """CUPS printing."""
    install: bool = Field(default=False)
