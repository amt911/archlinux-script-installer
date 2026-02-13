"""Models for pacman configuration."""
from pydantic import BaseModel, Field


class PacmanOptionsModel(BaseModel):
    """Individual pacman.conf options."""
    Parallel: bool = Field(default=True, description="Enable parallel downloads")
    Color: bool = Field(default=True, description="Enable coloured output")
    VerbosePkgLists: bool = Field(default=False, description="Enable verbose package lists")


class PacmanModel(BaseModel):
    """Pacman configuration."""
    options: PacmanOptionsModel = Field(default_factory=PacmanOptionsModel)
    multilib: bool = Field(default=False, description="Enable multilib repository")
