"""Models for bluetooth configuration."""
from pydantic import BaseModel, Field


class BluetoothModel(BaseModel):
    """Bluetooth configuration."""
    enable: bool = Field(default=False)
    package: str = Field(default="bluez")
