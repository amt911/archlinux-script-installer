"""Action: configure mkinitcpio.conf based on disk configuration.

Logic (same as old bash ``configure_mkinitcpio``):
  1. Move ``keyboard`` before ``autodetect``.
  2. If any partition has ``encrypt: true`` →
     replace ``udev`` → ``systemd``, ``keymap`` → ``sd-vconsole``,
     add ``sd-encrypt`` after ``block``, remove ``usr``/``resume``/``consolefont``.
  3. If root filesystem is ``btrfs`` → add ``btrfs`` hook after ``systemd`` or
     after ``udev``/``usr``/``resume`` depending on encryption.
  4. Rewrite HOOKS line (keeping old one commented) and run ``mkinitcpio -P``.

Idempotent: only touches the file if the computed HOOKS differ from
the current ones.
"""
from __future__ import annotations
import re
from typing import Any, Dict, List, Optional
from .abstract_action import AbstractAction
import subprocess


class MkinitcpioAction(AbstractAction):
    """Auto-configure /mnt/etc/mkinitcpio.conf from disk/encryption config."""

    MKINITCPIO_CONF = "/mnt/etc/mkinitcpio.conf"

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        # config is the full root config dict
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}

        self.has_encryption = self._detect_encryption(cfg)
        self.root_fs = self._detect_root_fs(cfg)

    # ------------------------------------------------------------------ #
    #  helpers to derive info from disk config
    # ------------------------------------------------------------------ #

    @staticmethod
    def _detect_encryption(cfg: Dict[str, Any]) -> bool:
        disks = cfg.get("disks", {})
        if isinstance(disks, dict):
            for disk in disks.get("disks", []):
                for part in disk.get("partitions", []):
                    if part.get("encrypt", False):
                        return True
        return False

    @staticmethod
    def _detect_root_fs(cfg: Dict[str, Any]) -> Optional[str]:
        disks = cfg.get("disks", {})
        if isinstance(disks, dict):
            for disk in disks.get("disks", []):
                for part in disk.get("partitions", []):
                    if part.get("mountpoint") == "/":
                        return part.get("filesystem")
        return None

    # ------------------------------------------------------------------ #
    #  hooks computation (mirrors old bash logic)
    # ------------------------------------------------------------------ #

    def _read_current_hooks(self) -> List[str]:
        try:
            with open(self.MKINITCPIO_CONF, "r") as f:
                for line in f:
                    m = re.match(r"^HOOKS=\((.+)\)", line)
                    if m:
                        return m.group(1).split()
        except FileNotFoundError:
            pass
        # sensible default
        return ["base", "udev", "autodetect", "modconf", "kms",
                "keyboard", "keymap", "consolefont", "block",
                "filesystems", "fsck"]

    def _compute_desired_hooks(self) -> List[str]:
        hooks = self._read_current_hooks()

        # 1. Move keyboard before autodetect
        if "keyboard" in hooks and "autodetect" in hooks:
            hooks = [h for h in hooks if h != "keyboard"]
            idx = hooks.index("autodetect")
            hooks.insert(idx, "keyboard")

        # 2. Encryption substitutions
        if self.has_encryption:
            new: List[str] = []
            for h in hooks:
                if h == "udev":
                    new.append("systemd")
                elif h == "keymap":
                    new.append("sd-vconsole")
                elif h == "block":
                    new.append(h)
                    new.append("sd-encrypt")
                elif h in ("usr", "resume", "consolefont"):
                    continue  # drop
                else:
                    new.append(h)
            hooks = new

        # 3. btrfs hook
        if self.root_fs == "btrfs" and "btrfs" not in hooks:
            # Find insertion point
            if self.has_encryption:
                insert_after = "systemd"
            else:
                insert_after = None
                for candidate in ("resume", "usr", "udev"):
                    if candidate in hooks:
                        insert_after = candidate
                        break
            if insert_after and insert_after in hooks:
                idx = hooks.index(insert_after) + 1
                hooks.insert(idx, "btrfs")
            else:
                # fallback: put after first hook
                hooks.insert(1, "btrfs")

        # deduplicate while preserving order
        seen: set = set()
        deduped: List[str] = []
        for h in hooks:
            if h not in seen:
                seen.add(h)
                deduped.append(h)
        return deduped

    # ------------------------------------------------------------------ #
    #  idempotency
    # ------------------------------------------------------------------ #

    @property
    def name(self) -> str:
        return "Mkinitcpio Configuration"

    @property
    def is_optional(self) -> bool:
        return True

    def is_needed(self) -> bool:
        return self._read_current_hooks() != self._compute_desired_hooks()

    def execute(self) -> None:
        desired = self._compute_desired_hooks()
        hooks_str = " ".join(desired)
        print(f"  Desired HOOKS=({hooks_str})")

        try:
            with open(self.MKINITCPIO_CONF, "r") as f:
                lines = f.readlines()
        except FileNotFoundError:
            lines = []

        with open(self.MKINITCPIO_CONF, "w") as f:
            for line in lines:
                if re.match(r"^HOOKS=", line):
                    f.write(f"# {line}")      # comment old line
                    f.write(f"HOOKS=({hooks_str})\n")
                else:
                    f.write(line)

        # Regenerate initramfs
        subprocess.run(["arch-chroot", "/mnt", "mkinitcpio", "-P"], check=True)

    def verify(self) -> bool:
        return self._read_current_hooks() == self._compute_desired_hooks()
