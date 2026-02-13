
from ..exceptions.exceptions import CommandNotFoundException
from shutil import which
import subprocess


class Command:
    """Thin wrapper around subprocess.run with optional arch-chroot support."""

    @staticmethod
    def _locate_binary(name: str) -> str:
        path = which(name)
        if not path:
            raise CommandNotFoundException(f"Binary not found: {name}")
        return path

    @staticmethod
    def execute(cmd: str, args: list[str], run_as_chroot: bool = False):
        """Run *cmd* with *args*, optionally inside ``arch-chroot /mnt``."""
        chroot_cmd: list[str] = []
        if run_as_chroot:
            chroot_path = Command._locate_binary("arch-chroot")
            chroot_cmd = [chroot_path, "/mnt"]

        return subprocess.run(
            chroot_cmd + [cmd, *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        