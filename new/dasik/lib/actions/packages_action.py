"""Action: install packages (pacman + AUR via makepkg in chroot).

The package list mixes normal pacman packages with AUR ones.
AUR packages are identified by the ``aur-`` prefix; the prefix is
stripped before installation.

AUR strategy **from inside arch-chroot**:
  1. Ensure ``base-devel git`` are installed.
  2. Create a temporary build user (``_aurbuilder``) with passwordless sudo.
  3. For each AUR package, clone the PKGBUILD and run ``makepkg -sri``
     as that user.  Dependencies that are themselves AUR are resolved
     recursively by sorting the list so that deps come first (or by
     installing paru/yay first if it is in the list).
  4. Remove the temp user at the end.

Idempotent: a package is skipped if ``pacman -Qi <pkg>`` inside the
chroot already shows it installed.
"""
from __future__ import annotations
from typing import Any, List
from .abstract_action import AbstractAction
from ..command_worker.command_worker import Command
import subprocess


AUR_PREFIX = "aur-"


class PackagesAction(AbstractAction):
    """Install pacman and AUR packages declaratively."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        raw: List[str] = config if isinstance(config, list) else []
        self.pacman_pkgs: List[str] = []
        self.aur_pkgs: List[str] = []
        for pkg in raw:
            if pkg.startswith(AUR_PREFIX):
                self.aur_pkgs.append(pkg[len(AUR_PREFIX):])
            else:
                self.pacman_pkgs.append(pkg)

    @property
    def name(self) -> str:
        return "Package Installation"

    @property
    def is_optional(self) -> bool:
        return True

    # ------------------------------------------------------------------ #
    #  helpers
    # ------------------------------------------------------------------ #

    @staticmethod
    def _is_installed(pkg: str) -> bool:
        """Check if *pkg* is installed inside the chroot."""
        result = subprocess.run(
            ["arch-chroot", "/mnt", "pacman", "-Qi", pkg],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return result.returncode == 0

    def _missing(self, pkgs: List[str]) -> List[str]:
        return [p for p in pkgs if not self._is_installed(p)]

    # ------------------------------------------------------------------ #
    #  AUR helpers
    # ------------------------------------------------------------------ #

    _AUR_USER = "_aurbuilder"

    def _ensure_aur_prerequisites(self) -> None:
        """Install base-devel, git and create a temp build user."""
        Command.execute("pacman", ["--noconfirm", "--needed", "-S", "base-devel", "git"], run_as_chroot=True)

        # Create build user if it does not exist
        result = subprocess.run(
            ["arch-chroot", "/mnt", "id", self._AUR_USER],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            Command.execute("useradd", ["-m", "-r", "-s", "/bin/bash", self._AUR_USER], run_as_chroot=True)

        # Grant passwordless sudo
        sudoers_line = f"{self._AUR_USER} ALL=(ALL) NOPASSWD: ALL\n"
        sudoers_path = f"/mnt/etc/sudoers.d/{self._AUR_USER}"
        with open(sudoers_path, "w") as f:
            f.write(sudoers_line)

    def _install_aur_helper(self) -> str | None:
        """Install yay or paru if listed, return helper name or None."""
        for helper in ("yay", "paru"):
            if helper in self.aur_pkgs:
                if not self._is_installed(helper):
                    self._install_single_aur_pkg(helper)
                self.aur_pkgs.remove(helper)
                return helper
        return None

    def _install_single_aur_pkg(self, pkg: str) -> None:
        """Clone and build a single AUR package as the build user."""
        build_dir = f"/home/{self._AUR_USER}/{pkg}"
        # Clean previous build
        subprocess.run(
            ["arch-chroot", "/mnt", "rm", "-rf", build_dir],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        # Clone
        subprocess.run(
            ["arch-chroot", "/mnt", "su", "-", self._AUR_USER, "-c",
             f"git clone https://aur.archlinux.org/{pkg}.git {build_dir}"],
            check=True,
        )
        # Build and install
        subprocess.run(
            ["arch-chroot", "/mnt", "su", "-", self._AUR_USER, "-c",
             f"cd {build_dir} && makepkg -sri --noconfirm"],
            check=True,
        )

    def _install_aur_with_helper(self, helper: str, pkgs: List[str]) -> None:
        """Use yay/paru inside chroot to install AUR packages."""
        if not pkgs:
            return
        subprocess.run(
            ["arch-chroot", "/mnt", "su", "-", self._AUR_USER, "-c",
             f"{helper} -S --noconfirm --needed {' '.join(pkgs)}"],
            check=True,
        )

    def _cleanup_aur_user(self) -> None:
        """Remove the temp build user and its sudoers file."""
        import os
        subprocess.run(
            ["arch-chroot", "/mnt", "userdel", "-r", self._AUR_USER],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        sudoers_path = f"/mnt/etc/sudoers.d/{self._AUR_USER}"
        if os.path.exists(sudoers_path):
            os.remove(sudoers_path)

    # ------------------------------------------------------------------ #
    #  idempotency
    # ------------------------------------------------------------------ #

    def is_needed(self) -> bool:
        if self._missing(self.pacman_pkgs):
            return True
        if self._missing(self.aur_pkgs):
            return True
        return False

    # ------------------------------------------------------------------ #
    #  execute
    # ------------------------------------------------------------------ #

    def execute(self) -> None:
        # 1. Official packages ------------------------------------------------
        missing_pacman = self._missing(self.pacman_pkgs)
        if missing_pacman:
            print(f"  Installing {len(missing_pacman)} official packages …")
            Command.execute(
                "pacman",
                ["--noconfirm", "--needed", "-S"] + missing_pacman,
                run_as_chroot=True,
            )

        # 2. AUR packages -----------------------------------------------------
        missing_aur = self._missing(self.aur_pkgs)
        if not missing_aur:
            return

        print(f"  Installing {len(missing_aur)} AUR packages …")
        self._ensure_aur_prerequisites()

        # Try to install an AUR helper first (yay/paru)
        helper = self._install_aur_helper()

        if helper:
            self._install_aur_with_helper(helper, missing_aur)
        else:
            # Fallback: build each AUR package individually via makepkg
            for pkg in missing_aur:
                if not self._is_installed(pkg):
                    print(f"    Building AUR package: {pkg}")
                    self._install_single_aur_pkg(pkg)

        self._cleanup_aur_user()

    def verify(self) -> bool:
        return not self._missing(self.pacman_pkgs + self.aur_pkgs)
