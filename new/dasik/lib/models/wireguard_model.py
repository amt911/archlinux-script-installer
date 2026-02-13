"""Models for WireGuard configuration."""
from typing import Optional
from pydantic import BaseModel, Field


class WireguardModel(BaseModel):
    """WireGuard VPN configuration."""
    enable: bool = Field(default=False)
    interface_name: str = Field(default="wg0", description="WireGuard interface name")
    config_content: Optional[str] = Field(
        default=None,
        description="Full content for /etc/wireguard/<interface>.conf"
    )
