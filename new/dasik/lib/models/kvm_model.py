"""Models for KVM configuration."""
from pydantic import BaseModel, Field


class KvmModel(BaseModel):
    """KVM virtualisation."""
    install: bool = Field(default=False)
