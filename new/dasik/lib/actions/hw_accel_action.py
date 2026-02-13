"""Action: enable hardware video acceleration.

Installs codec packages based on the ``drivers`` list and sets up
the recommended environment variables via profile.d / /etc/environment
(handled by DropFilesAction, this action only installs packages).

Idempotent: skips already-installed packages.
"""
from __future__ import annotations
import subprocess
from typing import Any, Dict, List
from .abstract_action import AbstractAction


# Maps driver → packages to install
_DRIVER_PKGS: Dict[str, List[str]] = {
    "nvidia": ["libva-nvidia-driver", "libva-utils", "vdpauinfo", "nvtop"],
    "intel":  ["intel-media-driver", "intel-gpu-tools", "libvdpau-va-gl", "libva-utils", "vdpauinfo"],
    "amd":    ["libva-mesa-driver", "mesa-vdpau", "libva-utils", "vdpauinfo"],
}


class HardwareAccelAction(AbstractAction):
    """Install HW-acceleration packages for the configured GPU drivers."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}
        self.enable: bool = cfg.get("enable", False)
        self.install_codecs: bool = cfg.get("install_codecs", True)
        # get drivers from root config via context
        self.drivers: List[str] = []
        if context and context.has("drivers"):
            self.drivers = context.get("drivers")

    @property
    def name(self) -> str:
        return "Hardware Acceleration"

    @property
    def is_optional(self) -> bool:
        return True

    def _desired_pkgs(self) -> List[str]:
        pkgs: List[str] = []
        for drv in self.drivers:
            pkgs.extend(_DRIVER_PKGS.get(drv, []))
        # deduplicate
        return list(dict.fromkeys(pkgs))

    def _missing_pkgs(self) -> List[str]:
        missing: List[str] = []
        for pkg in self._desired_pkgs():
            r = subprocess.run(
                ["arch-chroot", "/mnt", "pacman", "-Qi", pkg],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            if r.returncode != 0:
                missing.append(pkg)
        return missing

    def is_needed(self) -> bool:
        if not self.enable or not self.install_codecs:
            return False
        return bool(self._missing_pkgs())

    def execute(self) -> None:
        missing = self._missing_pkgs()
        if missing:
            print(f"  Installing HW-acceleration packages: {', '.join(missing)}")
            subprocess.run(
                ["arch-chroot", "/mnt", "pacman", "--noconfirm", "--needed", "-S"] + missing,
                check=True,
            )

    def verify(self) -> bool:
        return not self._missing_pkgs()
