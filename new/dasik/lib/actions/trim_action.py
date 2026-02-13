"""Action: enable periodic TRIM.

Idempotent: only enables fstrim.timer if not already enabled.
If the root partition is encrypted it also runs
``cryptsetup --allow-discards --persistent refresh <DM_NAME>``.
"""
from __future__ import annotations
import subprocess
from typing import Any, Dict
from .abstract_action import AbstractAction


class TrimAction(AbstractAction):
    """Enable SSD TRIM support."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}
        self.enable: bool = cfg.get("enable_trim", False) if isinstance(cfg, dict) else bool(config)

        # Detect encryption / dm name from disk config
        self.has_encryption = False
        self.dm_name = "cryptroot"
        disks = cfg.get("disks", {}) if isinstance(cfg, dict) else {}
        if isinstance(disks, dict):
            for disk in disks.get("disks", []):
                for part in disk.get("partitions", []):
                    if part.get("encrypt"):
                        self.has_encryption = True
                        self.dm_name = part.get("luks_name", "cryptroot")

    @property
    def name(self) -> str:
        return "Enable TRIM"

    @property
    def is_optional(self) -> bool:
        return True

    @staticmethod
    def _timer_enabled() -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "is-enabled", "fstrim.timer"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        return r.stdout.decode().strip() == "enabled"

    def is_needed(self) -> bool:
        if not self.enable:
            return False
        return not self._timer_enabled()

    def execute(self) -> None:
        # Ensure util-linux is installed (provides fstrim)
        subprocess.run(
            ["arch-chroot", "/mnt", "pacman", "--noconfirm", "--needed", "-S", "util-linux"],
            check=True,
        )
        subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "enable", "fstrim.timer"],
            check=True,
        )
        if self.has_encryption:
            subprocess.run(
                ["arch-chroot", "/mnt", "cryptsetup",
                 "--allow-discards", "--persistent", "refresh", self.dm_name],
                check=False,  # may not work outside real system
            )

    def verify(self) -> bool:
        return self._timer_enabled()
