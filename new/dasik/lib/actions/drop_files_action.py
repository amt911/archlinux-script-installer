"""Action: write declarative files (udev rules, modprobe, profile.d, /etc/environment).

Each list entry becomes one file under the corresponding directory.
Idempotent: files are only (re)written when their content differs.
"""
from __future__ import annotations
import hashlib
import os
from pathlib import Path
from typing import Any, Dict, List, Tuple
from .abstract_action import AbstractAction


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()


class DropFilesAction(AbstractAction):
    """Write config snippets into /mnt/etc/... directories."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        # config is the full root config dict
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}

        self.udev_rules: List[str] = cfg.get("udev_rules", [])
        self.modprobe_conf: List[str] = cfg.get("modprobe_conf", [])
        self.profile_d: List[str] = cfg.get("profile_d", [])
        self.etc_env_lines: List[str] = cfg.get("etc_environment", [])

    @property
    def name(self) -> str:
        return "Drop Config Files"

    @property
    def is_optional(self) -> bool:
        return True

    # ------------------------------------------------------------------ #

    def _plan(self) -> List[Tuple[str, str]]:
        """Return list of (absolute_path, desired_content) tuples."""
        files: List[Tuple[str, str]] = []

        for idx, content in enumerate(self.udev_rules, start=1):
            files.append((f"/mnt/etc/udev/rules.d/99-dasik-{idx:02d}.rules", content + "\n"))

        for idx, content in enumerate(self.modprobe_conf, start=1):
            files.append((f"/mnt/etc/modprobe.d/dasik-{idx:02d}.conf", content + "\n"))

        for idx, content in enumerate(self.profile_d, start=1):
            files.append((f"/mnt/etc/profile.d/dasik-{idx:02d}.sh", content + "\n"))

        if self.etc_env_lines:
            desired = "\n".join(self.etc_env_lines) + "\n"
            files.append(("/mnt/etc/environment", desired))

        return files

    def _needs_write(self, path: str, desired: str) -> bool:
        if not os.path.exists(path):
            return True
        with open(path, "r") as f:
            return _sha256(f.read()) != _sha256(desired)

    # ------------------------------------------------------------------ #

    def is_needed(self) -> bool:
        return any(self._needs_write(p, c) for p, c in self._plan())

    def execute(self) -> None:
        for path, content in self._plan():
            if self._needs_write(path, content):
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w") as f:
                    f.write(content)
                print(f"  Wrote {path}")

    def verify(self) -> bool:
        return not any(self._needs_write(p, c) for p, c in self._plan())
