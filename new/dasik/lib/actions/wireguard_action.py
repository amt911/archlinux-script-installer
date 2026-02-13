"""Action: install and configure WireGuard.

Installs wireguard-tools, writes the interface configuration file and
optionally enables the wg-quick systemd service.

Idempotent: skips if config file already has the desired content and
service is enabled.
"""
from __future__ import annotations
import hashlib
import os
import subprocess
from typing import Any, Dict
from .abstract_action import AbstractAction


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


class WireguardAction(AbstractAction):
    """Configure WireGuard declaratively."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}
        self.enable: bool = cfg.get("enable", False)
        self.iface: str = cfg.get("interface_name", "wg0")
        self.config_content: str = cfg.get("config_content", "") or ""

    @property
    def name(self) -> str:
        return "WireGuard"

    @property
    def is_optional(self) -> bool:
        return True

    def _conf_path(self) -> str:
        return f"/mnt/etc/wireguard/{self.iface}.conf"

    def _service_name(self) -> str:
        return f"wg-quick@{self.iface}.service"

    def _pkg_installed(self) -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "pacman", "-Qi", "wireguard-tools"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        return r.returncode == 0

    def _service_enabled(self) -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "is-enabled", self._service_name()],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        return r.stdout.decode().strip() == "enabled"

    def _config_matches(self) -> bool:
        path = self._conf_path()
        if not os.path.exists(path):
            return False
        with open(path, "r") as f:
            return _sha256(f.read()) == _sha256(self.config_content + "\n")

    # -----------------------------------------------------------------------

    def is_needed(self) -> bool:
        if not self.enable:
            return False
        if not self._pkg_installed():
            return True
        if self.config_content and not self._config_matches():
            return True
        if not self._service_enabled():
            return True
        return False

    def execute(self) -> None:
        if not self._pkg_installed():
            subprocess.run(
                ["arch-chroot", "/mnt", "pacman", "--noconfirm", "--needed", "-S", "wireguard-tools"],
                check=True,
            )

        if self.config_content:
            conf_dir = os.path.dirname(self._conf_path())
            os.makedirs(conf_dir, exist_ok=True)
            with open(self._conf_path(), "w") as f:
                f.write(self.config_content + "\n")
            # Restrict permissions (private key inside)
            os.chmod(self._conf_path(), 0o600)
            print(f"  Wrote {self._conf_path()}")

        if not self._service_enabled():
            subprocess.run(
                ["arch-chroot", "/mnt", "systemctl", "enable", self._service_name()],
                check=True,
            )

    def verify(self) -> bool:
        return self._pkg_installed() and self._service_enabled()
