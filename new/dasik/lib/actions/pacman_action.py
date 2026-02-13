"""Action: configure pacman (parallel downloads, color, multilib).

Idempotent: only edits lines that differ from the desired state.
"""
import re
from typing import Any
from .abstract_action import AbstractAction


class PacmanAction(AbstractAction):
    """Configure /mnt/etc/pacman.conf declaratively."""

    PACMAN_CONF = "/mnt/etc/pacman.conf"

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        opts = config.get("options", {}) if isinstance(config, dict) else {}
        self.parallel = opts.get("Parallel", True)
        self.color = opts.get("Color", True)
        self.verbose = opts.get("VerbosePkgLists", False)
        self.multilib = config.get("multilib", False) if isinstance(config, dict) else False

    @property
    def name(self) -> str:
        return "Pacman Configuration"

    @property
    def is_optional(self) -> bool:
        return True

    # ------------------------------------------------------------------ #

    def _read_conf(self) -> str:
        with open(self.PACMAN_CONF, "r") as f:
            return f.read()

    def _write_conf(self, content: str) -> None:
        with open(self.PACMAN_CONF, "w") as f:
            f.write(content)

    # ------------------------------------------------------------------ #

    def _option_active(self, text: str, option: str) -> bool:
        """Return True if *option* is uncommented in pacman.conf."""
        return bool(re.search(rf"^\s*{option}", text, re.MULTILINE))

    def _multilib_active(self, text: str) -> bool:
        # [multilib] block: both header and Include must be uncommented
        m = re.search(r"^\[multilib\]\s*\n\s*Include", text, re.MULTILINE)
        return m is not None

    # ------------------------------------------------------------------ #

    def is_needed(self) -> bool:
        try:
            text = self._read_conf()
        except FileNotFoundError:
            return True

        if self.parallel and not self._option_active(text, "ParallelDownloads"):
            return True
        if self.color and not self._option_active(text, "Color"):
            return True
        if self.verbose and not self._option_active(text, "VerbosePkgLists"):
            return True
        if self.multilib and not self._multilib_active(text):
            return True
        return False

    def execute(self) -> None:
        text = self._read_conf()

        # Uncomment options -------------------------------------------------
        for flag, option in [
            (self.parallel, "ParallelDownloads"),
            (self.color, "Color"),
            (self.verbose, "VerbosePkgLists"),
        ]:
            if flag:
                text = re.sub(
                    rf"^#\s*({option}.*)", r"\1", text, flags=re.MULTILINE
                )

        # Enable multilib ----------------------------------------------------
        if self.multilib and not self._multilib_active(text):
            # Uncomment [multilib] and the Include line right after it
            text = re.sub(
                r"^#\s*\[multilib\]\s*\n#\s*(Include\s*=.*)",
                r"[multilib]\n\1",
                text,
                flags=re.MULTILINE,
            )

        self._write_conf(text)

    def verify(self) -> bool:
        try:
            text = self._read_conf()
        except FileNotFoundError:
            return False
        if self.parallel and not self._option_active(text, "ParallelDownloads"):
            return False
        if self.color and not self._option_active(text, "Color"):
            return False
        if self.multilib and not self._multilib_active(text):
            return False
        return True
