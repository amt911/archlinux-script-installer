"""Action: install KVM / QEMU / libvirt / virt-manager.

Same packages and logic as the old ``install_kvm()`` bash function.
Idempotent: skips if all packages are already installed and services enabled.
"""
from __future__ import annotations
import subprocess
from typing import Any, Dict, List
from .abstract_action import AbstractAction


_KVM_PKGS = [
    "qemu-full", "qemu-block-gluster", "qemu-block-iscsi", "samba",
    "qemu-guest-agent", "qemu-user-static",
    # UEFI + TPM + Secure Boot
    "edk2-ovmf", "swtpm", "virt-firmware",
    # Libvirt
    "libvirt", "virt-manager",
    # Libvirt deps
    "iptables-nft", "dnsmasq", "openbsd-netcat", "dmidecode",
]


class KvmAction(AbstractAction):
    """Install KVM virtualisation stack."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}
        self.install: bool = cfg.get("install", False)

    @property
    def name(self) -> str:
        return "KVM Installation"

    @property
    def is_optional(self) -> bool:
        return True

    def _missing_pkgs(self) -> List[str]:
        missing: List[str] = []
        for pkg in _KVM_PKGS:
            r = subprocess.run(
                ["arch-chroot", "/mnt", "pacman", "-Qi", pkg],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            if r.returncode != 0:
                missing.append(pkg)
        return missing

    @staticmethod
    def _service_enabled(unit: str) -> bool:
        r = subprocess.run(
            ["arch-chroot", "/mnt", "systemctl", "is-enabled", unit],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
        return r.stdout.decode().strip() == "enabled"

    def is_needed(self) -> bool:
        if not self.install:
            return False
        if self._missing_pkgs():
            return True
        if not self._service_enabled("libvirtd.service"):
            return True
        return False

    def execute(self) -> None:
        missing = self._missing_pkgs()
        if missing:
            print(f"  Installing KVM packages: {', '.join(missing)}")
            subprocess.run(
                ["arch-chroot", "/mnt", "pacman", "--noconfirm", "--needed", "-S"] + missing,
                check=True,
            )
        # Enable services
        for unit in ("libvirtd.service", "virtlogd.service"):
            if not self._service_enabled(unit):
                subprocess.run(
                    ["arch-chroot", "/mnt", "systemctl", "enable", unit],
                    check=True,
                )

        # Write modprobe for nested virtualisation
        self._setup_nested_virt()

    def _setup_nested_virt(self) -> None:
        """Enable nested virtualisation via modprobe config."""
        import os
        # Detect CPU vendor inside chroot
        try:
            with open("/mnt/proc/cpuinfo", "r") as f:
                cpuinfo = f.read()
        except FileNotFoundError:
            # Fallback: read host cpuinfo
            with open("/proc/cpuinfo", "r") as f:
                cpuinfo = f.read()

        cpu_mod = "kvm_intel" if "GenuineIntel" in cpuinfo else "kvm_amd"
        conf_path = "/mnt/etc/modprobe.d/dasik-nested-virt.conf"
        desired = f"options {cpu_mod} nested=1\n"
        if os.path.exists(conf_path):
            with open(conf_path, "r") as f:
                if f.read() == desired:
                    return
        with open(conf_path, "w") as f:
            f.write(desired)

    def verify(self) -> bool:
        return not self._missing_pkgs() and self._service_enabled("libvirtd.service")
