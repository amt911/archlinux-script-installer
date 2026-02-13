"""Models for user configuration."""
from typing import List, Optional
from pydantic import BaseModel, Field


class UserModel(BaseModel):
    """A system user to create."""
    username: str = Field(..., description="Login name")
    password: str = Field(..., description="Password (plain text, will be hashed at creation)")
    shell: str = Field(default="/bin/bash", description="Login shell path")
    groups: List[str] = Field(default_factory=list, description="Additional groups")
