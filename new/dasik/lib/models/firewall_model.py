"""Models for firewall configuration."""
from typing import List
from pydantic import BaseModel, Field


class FirewallModel(BaseModel):
    """Firewalld configuration."""
    enable: bool = Field(default=False)
    remove_services: List[str] = Field(
        default_factory=list,
        description="Services to remove from the default zone (e.g. ssh)"
    )
    rich_rules: List[str] = Field(
        default_factory=list,
        description="Rich rules to add (firewall-cmd --add-rich-rule syntax)"
    )
    allowed_services: List[str] = Field(
        default_factory=list,
        description="Services to allow in the default zone (e.g. syncthing)"
    )
