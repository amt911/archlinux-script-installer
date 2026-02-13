"""Models for Microsoft fonts configuration."""
from typing import Optional
from pydantic import BaseModel, Field


class MicrosoftFontsModel(BaseModel):
    """Microsoft fonts installation from a Windows ISO."""
    install: bool = Field(default=False)
    source_iso: Optional[str] = Field(default=None, description="Path to Windows ISO")
