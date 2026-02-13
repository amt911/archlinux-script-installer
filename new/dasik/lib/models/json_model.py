from typing import Optional, List
from pydantic import BaseModel, Field

from .locale_model import LocaleModel
from .timezone_model import TimezoneModel
from .network_model import NetworkModel
from .disk_model import DisksConfiguration
from .user_model import UserModel
from .pacman_model import PacmanModel
from .systemd_model import SystemdModel
from .bluetooth_model import BluetoothModel
from .hw_accel_model import HardwareAccelerationModel
from .kvm_model import KvmModel
from .cups_model import CupsModel
from .ms_fonts_model import MicrosoftFontsModel
from .firewall_model import FirewallModel
from .wireguard_model import WireguardModel


class JsonModel(BaseModel):
    """Root configuration model – validated with pydantic."""

    # --- existing mandatory fields ---
    locales: LocaleModel
    timezone: TimezoneModel
    network: NetworkModel
    hostname: str
    enable_microcode: bool = False

    # --- existing optional fields ---
    metadata: Optional[dict] = None
    disks: Optional[DisksConfiguration] = None
    notes: Optional[str] = None

    # --- new fields ---
    users: List[UserModel] = Field(default_factory=list)
    drivers: List[str] = Field(default_factory=list, description="GPU driver selection")
    packages: List[str] = Field(default_factory=list, description="Packages to install (aur- prefix for AUR)")
    bootloader: str = Field(default="grub", description="grub | sd-boot")

    # Files / lines to drop on the target system
    udev_rules: List[str] = Field(default_factory=list)
    modprobe_conf: List[str] = Field(default_factory=list)
    profile_d: List[str] = Field(default_factory=list)
    etc_environment: List[str] = Field(default_factory=list)
    kernel_cmdline: List[str] = Field(default_factory=list)

    # Toggles
    enable_trim: bool = False

    # Sub-models
    pacman: Optional[PacmanModel] = None
    systemd: Optional[SystemdModel] = None
    bluetooth: Optional[BluetoothModel] = None
    hardware_acceleration: Optional[HardwareAccelerationModel] = None
    kvm: Optional[KvmModel] = None
    cups: Optional[CupsModel] = None
    microsoft_fonts: Optional[MicrosoftFontsModel] = None
    firewall: Optional[FirewallModel] = None
    wireguard: Optional[WireguardModel] = None