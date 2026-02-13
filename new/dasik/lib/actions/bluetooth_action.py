"""Action: install and enable bluetooth.

Idempotent: skips if package is installed and service is enabled.
"""
from __future__ import annotations
import subprocess
from typing import Any, Dict
from .abstract_action import AbstractAction


class BluetoothAction(AbstractAction):
    """Install bluetooth packages and enable the service."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}
        self.enable: bool = cfg.get("enable", False)
        self.package: str = cfg.get("package", "bluez")

    @property
    def name(self) -> str:
        return "Bluetooth"

    @property
    def is_optional(self) -> bool:
        return True

    def _pkg_installed(self) -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "pacman", "-Qi", self.package],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        return r.returncode == 0

    def _service_enabled(self) -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "is-enabled", "bluetooth.service"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        return r.stdout.decode().strip() == "enabled"

    def is_needed(self) -> bool:
        if not self.enable:
            return False
        return not self._pkg_installed() or not self._service_enabled()

    def execute(self) -> None:
        subprocess.run(
            ["arch-chroot", "/mnt", "pacman", "--noconfirm", "--needed", "-S",
             self.package, "bluez-utils"],
            check=True,
        )
        subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "enable", "bluetooth.service"],
            check=True,
        )

    def verify(self) -> bool:
        return self._pkg_installed() and self._service_enabled()
