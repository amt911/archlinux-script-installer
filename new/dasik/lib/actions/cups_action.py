"""Action: install CUPS + scanner packages.

Idempotent: skips if packages are installed and cups.socket is enabled.
"""
from __future__ import annotations
import subprocess
from typing import Any, Dict, List
from .abstract_action import AbstractAction


_CUPS_PKGS = ["cups", "cups-pdf", "system-config-printer", "sane", "sane-airscan"]


class CupsAction(AbstractAction):
    """Install CUPS printing and SANE scanning."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}
        self.install: bool = cfg.get("install", False)

    @property
    def name(self) -> str:
        return "CUPS / Scanning"

    @property
    def is_optional(self) -> bool:
        return True

    def _missing_pkgs(self) -> List[str]:
        missing: List[str] = []
        for pkg in _CUPS_PKGS:
            r = subprocess.run(
                ["arch-chroot", "/mnt", "pacman", "-Qi", pkg],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            if r.returncode != 0:
                missing.append(pkg)
        return missing

    @staticmethod
    def _socket_enabled() -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "is-enabled", "cups.socket"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        return r.stdout.decode().strip() == "enabled"

    def is_needed(self) -> bool:
        if not self.install:
            return False
        return bool(self._missing_pkgs()) or not self._socket_enabled()

    def execute(self) -> None:
        missing = self._missing_pkgs()
        if missing:
            subprocess.run(
                ["arch-chroot", "/mnt", "pacman", "--noconfirm", "--needed", "-S"] + missing,
                check=True,
            )
        if not self._socket_enabled():
            subprocess.run(
                ["arch-chroot", "/mnt", "systemctl", "enable", "cups.socket"],
                check=True,
            )

    def verify(self) -> bool:
        return not self._missing_pkgs() and self._socket_enabled()
