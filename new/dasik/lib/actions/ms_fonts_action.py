"""Action: install Microsoft fonts from a Windows ISO.

Follows the same procedure as the old bash ``install_ms_fonts()`` but
driven purely from the JSON ``source_iso`` path.

Idempotent: skips if /mnt/usr/local/share/fonts/WindowsFonts/ is populated.
"""
from __future__ import annotations
import os
import subprocess
from typing import Any, Dict
from .abstract_action import AbstractAction


class MicrosoftFontsAction(AbstractAction):
    """Extract and install MS fonts from a Windows ISO."""

    FONTS_DIR = "/mnt/usr/local/share/fonts/WindowsFonts"

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        cfg: Dict[str, Any] = config if isinstance(config, dict) else {}
        self.install: bool = cfg.get("install", False)
        self.source_iso: str = cfg.get("source_iso", "")

    @property
    def name(self) -> str:
        return "Microsoft Fonts"

    @property
    def is_optional(self) -> bool:
        return True

    def is_needed(self) -> bool:
        if not self.install:
            return False
        if not self.source_iso:
            print("  WARNING: microsoft_fonts.install is true but no source_iso specified")
            return False
        # Consider done if directory exists and has > 0 files
        if os.path.isdir(self.FONTS_DIR):
            entries = os.listdir(self.FONTS_DIR)
            if len(entries) > 10:  # typical Windows has ~200 font files
                return False
        return True

    def execute(self) -> None:
        # Ensure 7zip is installed inside chroot
        subprocess.run(
            ["arch-chroot", "/mnt", "pacman", "--noconfirm", "--needed", "-S", "7zip"],
            check=True,
        )

        tmp = "/mnt/tmp/ms-fonts-work"
        os.makedirs(tmp, exist_ok=True)

        iso_path = self.source_iso
        # If it's a host path, copy into chroot tmp first
        if not iso_path.startswith("/mnt"):
            dest = f"{tmp}/{os.path.basename(iso_path)}"
            subprocess.run(["cp", iso_path, dest], check=True)
            iso_inner = f"/tmp/ms-fonts-work/{os.path.basename(iso_path)}"
        else:
            iso_inner = iso_path.replace("/mnt", "", 1)

        # Extract install.wim from ISO
        subprocess.run(
            ["arch-chroot", "/mnt", "7z", "e", iso_inner,
             "sources/install.wim", f"-o/tmp/ms-fonts-work"],
            check=True,
        )
        # Extract fonts from install.wim
        subprocess.run(
            ["arch-chroot", "/mnt", "7z", "e", "/tmp/ms-fonts-work/install.wim",
             '1/Windows/Fonts/*.ttf', '1/Windows/Fonts/*.ttc',
             '1/Windows/System32/Licenses/neutral/**/license.rtf',
             "-o/tmp/ms-fonts-work/fonts/"],
            check=True,
        )

        # Copy into system fonts dir
        fonts_dest = self.FONTS_DIR.replace("/mnt", "", 1)
        subprocess.run(
            ["arch-chroot", "/mnt", "mkdir", "-p", fonts_dest], check=True,
        )
        subprocess.run(
            ["arch-chroot", "/mnt", "sh", "-c",
             f"cp /tmp/ms-fonts-work/fonts/* {fonts_dest}/ && "
             f"chmod 644 {fonts_dest}/*"],
            check=True,
        )

        # Refresh font cache
        subprocess.run(["arch-chroot", "/mnt", "fc-cache", "--force"], check=True)

        # Cleanup
        subprocess.run(["rm", "-rf", tmp], check=False)

    def verify(self) -> bool:
        return os.path.isdir(self.FONTS_DIR) and len(os.listdir(self.FONTS_DIR)) > 10
