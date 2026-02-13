"""Action: install and configure firewalld.

Applies:
  - remove services from default zone
  - add rich rules
  - allow services
all from the declarative JSON.

Idempotent: queries current firewalld config before making changes.
"""
from __future__ import annotations
import subprocess
from typing import Any, Dict, List
from .abstract_action import AbstractAction


class FirewallAction(AbstractAction):
    """Configure firewalld declaratively."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}
        self.enable: bool = cfg.get("enable", False)
        self.remove_services: List[str] = cfg.get("remove_services", [])
        self.rich_rules: List[str] = cfg.get("rich_rules", [])
        self.allowed_services: List[str] = cfg.get("allowed_services", [])

    @property
    def name(self) -> str:
        return "Firewall (firewalld)"

    @property
    def is_optional(self) -> bool:
        return True

    # helpers ---------------------------------------------------------------

    @staticmethod
    def _pkg_installed() -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "pacman", "-Qi", "firewalld"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        return r.returncode == 0

    @staticmethod
    def _service_enabled() -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "is-enabled", "firewalld.service"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        return r.stdout.decode().strip() == "enabled"

    def _get_active_services(self, zone: str = "public") -> List[str]:
        """List currently allowed services in the permanent zone config."""
        r = subprocess.run(
            ["arch-chroot", "/mnt", "firewall-offline-cmd",
             f"--zone={zone}", "--list-services"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        if r.returncode != 0:
            return []
        return r.stdout.decode().strip().split()

    def _get_rich_rules(self, zone: str = "public") -> List[str]:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "firewall-offline-cmd",
             f"--zone={zone}", "--list-rich-rules"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        if r.returncode != 0:
            return []
        return [line.strip() for line in r.stdout.decode().strip().splitlines() if line.strip()]

    # idempotency -----------------------------------------------------------

    def is_needed(self) -> bool:
        if not self.enable:
            return False
        if not self._pkg_installed():
            return True
        if not self._service_enabled():
            return True
        # Check service removals
        active = self._get_active_services()
        for svc in self.remove_services:
            if svc in active:
                return True
        # Check allowed services
        for svc in self.allowed_services:
            if svc not in active:
                return True
        # Check rich rules
        current_rules = self._get_rich_rules()
        for rule in self.rich_rules:
            if rule not in current_rules:
                return True
        return False

    def execute(self) -> None:
        # Install firewalld
        if not self._pkg_installed():
            subprocess.run(
                ["arch-chroot", "/mnt", "pacman", "--noconfirm", "--needed", "-S", "firewalld"],
                check=True,
            )

        # Enable service
        if not self._service_enabled():
            subprocess.run(
                ["arch-chroot", "/mnt", "systemctl", "enable", "firewalld.service"],
                check=True,
            )

        # Remove services (use offline-cmd since firewalld is not running in chroot)
        for svc in self.remove_services:
            subprocess.run(
                ["arch-chroot", "/mnt", "firewall-offline-cmd",
                 "--zone=public", f"--remove-service={svc}"],
                check=False,
            )

        # Add rich rules
        for rule in self.rich_rules:
            subprocess.run(
                ["arch-chroot", "/mnt", "firewall-offline-cmd",
                 "--zone=public", f"--add-rich-rule={rule}"],
                check=False,
            )

        # Add allowed services
        for svc in self.allowed_services:
            subprocess.run(
                ["arch-chroot", "/mnt", "firewall-offline-cmd",
                 "--zone=public", f"--add-service={svc}"],
                check=False,
            )

    def verify(self) -> bool:
        return self._pkg_installed() and self._service_enabled()
