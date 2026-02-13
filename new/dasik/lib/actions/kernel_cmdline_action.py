"""Action: configure kernel command line parameters (bootloader entries).

Supports both GRUB and systemd-boot.
Auto-derives parameters from disk config (encryption, btrfs) and
merges them with explicit ``kernel_cmdline`` entries from the JSON.

Idempotent: only writes when the desired parameters are missing.
"""
from __future__ import annotations
import os
import re
import subprocess
from typing import Any, Dict, List, Optional
from .abstract_action import AbstractAction


class KernelCmdlineAction(AbstractAction):
    """Set kernel command line parameters declaratively."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}

        self.bootloader: str = cfg.get("bootloader", "grub")
        self.explicit_params: List[str] = cfg.get("kernel_cmdline", [])

        # Auto-derive from disk config
        self._auto_params = self._derive_from_disks(cfg)
        self.desired_params = self._merge(self._auto_params, self.explicit_params)

    # ------------------------------------------------------------------ #
    #  auto-derivation from disk config (same logic as old bash)
    # ------------------------------------------------------------------ #

    @staticmethod
    def _derive_from_disks(cfg: Dict[str, Any]) -> List[str]:
        params: List[str] = []
        disks = cfg.get("disks", {})
        if not isinstance(disks, dict):
            return params

        for disk in disks.get("disks", []):
            for part in disk.get("partitions", []):
                mp = part.get("mountpoint")
                if mp != "/":
                    continue
                # Encryption
                if part.get("encrypt"):
                    dm_name = part.get("luks_name", "cryptroot")
                    # UUID will be resolved at runtime; for now use placeholder
                    params.append(f"rd.luks.name=<ROOT_UUID>={dm_name}")
                    params.append(f"root=/dev/mapper/{dm_name} rw")

                # btrfs rootflags
                fs = part.get("filesystem", "")
                if fs == "btrfs":
                    subvols = part.get("btrfs_subvolumes", [])
                    root_sv = next((s for s in subvols if s.get("mountpoint") == "/"), None)
                    sv_name = root_sv["name"] if root_sv else "@"
                    options = root_sv.get("mount_options", ["compress-force=zstd"]) if root_sv else ["compress-force=zstd"]
                    opts_str = ",".join(options + [f"subvol={sv_name}"])
                    params.append(f"rootflags={opts_str}")
        return params

    @staticmethod
    def _merge(auto: List[str], explicit: List[str]) -> List[str]:
        """Merge auto-derived and explicit params, explicit wins on conflict."""
        # Use explicit as base; auto params only added if no explicit
        # param with the same key exists
        explicit_keys = set()
        for p in explicit:
            key = p.split("=")[0] if "=" in p else p
            explicit_keys.add(key)

        merged = list(explicit)
        for p in auto:
            key = p.split("=")[0] if "=" in p else p
            if key not in explicit_keys:
                merged.append(p)
        return merged

    # ------------------------------------------------------------------ #
    #  file manipulation
    # ------------------------------------------------------------------ #

    def _grub_file(self) -> str:
        return "/mnt/etc/default/grub"

    def _sdboot_entries(self) -> List[str]:
        entries_dir = "/mnt/boot/loader/entries"
        if os.path.isdir(entries_dir):
            return [os.path.join(entries_dir, f) for f in os.listdir(entries_dir) if f.endswith(".conf")]
        return []

    def _current_params_grub(self) -> str:
        path = self._grub_file()
        if not os.path.exists(path):
            return ""
        with open(path, "r") as f:
            for line in f:
                m = re.match(r'^GRUB_CMDLINE_LINUX="(.+)"', line)
                if m:
                    return m.group(1)
        return ""

    def _current_params_sdboot(self, entry_file: str) -> str:
        if not os.path.exists(entry_file):
            return ""
        with open(entry_file, "r") as f:
            for line in f:
                if line.startswith("options "):
                    return line[len("options "):].strip()
        return ""

    def _param_present(self, current: str, param: str) -> bool:
        """Check if a kernel param (key=val or flag) is already present."""
        if "=" in param:
            key = param.split("=")[0]
            return key in current
        return param in current.split()

    def _missing_params(self) -> List[str]:
        if self.bootloader == "grub":
            current = self._current_params_grub()
        else:
            entries = self._sdboot_entries()
            current = self._current_params_sdboot(entries[0]) if entries else ""
        return [p for p in self.desired_params if not self._param_present(current, p)]

    # ------------------------------------------------------------------ #

    @property
    def name(self) -> str:
        return "Kernel Command Line"

    @property
    def is_optional(self) -> bool:
        return True

    def is_needed(self) -> bool:
        if not self.desired_params:
            return False
        return bool(self._missing_params())

    def execute(self) -> None:
        missing = self._missing_params()
        if not missing:
            return

        addition = " ".join(missing)

        if self.bootloader == "grub":
            self._append_grub(addition)
            # Regenerate grub config
            subprocess.run(["arch-chroot", "/mnt", "grub-mkconfig", "-o", "/boot/grub/grub.cfg"], check=True)
        else:
            for entry in self._sdboot_entries():
                self._append_sdboot(entry, addition)

    def _append_grub(self, addition: str) -> None:
        path = self._grub_file()
        with open(path, "r") as f:
            text = f.read()
        # Append to GRUB_CMDLINE_LINUX
        text = re.sub(
            r'^(GRUB_CMDLINE_LINUX=")(.*)"',
            rf'\1\2 {addition}"',
            text,
            flags=re.MULTILINE,
        )
        with open(path, "w") as f:
            f.write(text)

    def _append_sdboot(self, entry_file: str, addition: str) -> None:
        with open(entry_file, "r") as f:
            lines = f.readlines()
        with open(entry_file, "w") as f:
            for line in lines:
                if line.startswith("options "):
                    f.write(line.rstrip() + " " + addition + "\n")
                else:
                    f.write(line)

    def verify(self) -> bool:
        return not self._missing_params()
