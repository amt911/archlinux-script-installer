"""Action: enable systemd units declaratively.

Idempotent: only enables units that are not already enabled.
"""
from typing import Any, List
from .abstract_action import AbstractAction
import subprocess


class SystemdAction(AbstractAction):
    """Enable systemd services / sockets / timers inside chroot."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg = config if isinstance(config, dict) else {}
        self.units: List[str] = cfg.get("enable_units", [])
        self.sockets: List[str] = cfg.get("enable_sockets", [])

    @property
    def name(self) -> str:
        return "Systemd Units"

    @property
    def is_optional(self) -> bool:
        return True

    # helpers ---------------------------------------------------------------

    @staticmethod
    def _is_enabled(unit: str) -> bool:
        result = subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "is-enabled", unit],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        return result.stdout.decode().strip() == "enabled"

    def _all_units(self) -> List[str]:
        return self.units + self.sockets

    def _pending(self) -> List[str]:
        return [u for u in self._all_units() if not self._is_enabled(u)]

    # idempotency -----------------------------------------------------------

    def is_needed(self) -> bool:
        return bool(self._pending())

    def execute(self) -> None:
        for unit in self._pending():
            print(f"  Enabling {unit} …")
            subprocess.run(
                ["arch-chroot", "/mnt", "systemctl", "enable", unit],
                check=True,
            )

    def verify(self) -> bool:
        return not self._pending()
