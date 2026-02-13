"""Action: create users declaratively.

Idempotent: skips users that already exist with the correct shell/groups.
"""
from typing import Any, Dict, List
from .abstract_action import AbstractAction
from ..command_worker.command_worker import Command


class UsersAction(AbstractAction):
    """Create system users from the declarative config."""

    def __init__(self, config: Any, context=None):
        super().__init__(config, context)
        # config is the list of user dicts
        self.users: List[Dict[str, Any]] = config if isinstance(config, list) else []

    @property
    def name(self) -> str:
        return "User Creation"

    @property
    def is_optional(self) -> bool:
        return True

    # ------------------------------------------------------------------ #
    #  helpers
    # ------------------------------------------------------------------ #

    @staticmethod
    def _user_exists(username: str) -> bool:
        """Check if user exists inside /mnt."""
        try:
            with open("/mnt/etc/passwd", "r") as f:
                for line in f:
                    if line.startswith(f"{username}:"):
                        return True
        except FileNotFoundError:
            pass
        return False

    @staticmethod
    def _get_user_shell(username: str) -> str:
        try:
            with open("/mnt/etc/passwd", "r") as f:
                for line in f:
                    if line.startswith(f"{username}:"):
                        return line.strip().split(":")[-1]
        except FileNotFoundError:
            pass
        return ""

    @staticmethod
    def _get_user_groups(username: str) -> set:
        groups: set = set()
        try:
            with open("/mnt/etc/group", "r") as f:
                for line in f:
                    fields = line.strip().split(":")
                    members = fields[3].split(",") if len(fields) > 3 and fields[3] else []
                    if username in members:
                        groups.add(fields[0])
        except FileNotFoundError:
            pass
        return groups

    # ------------------------------------------------------------------ #
    #  idempotency
    # ------------------------------------------------------------------ #

    def is_needed(self) -> bool:
        for u in self.users:
            uname = u["username"]
            if uname == "root":
                continue  # root always exists; password set separately
            if not self._user_exists(uname):
                return True
            if self._get_user_shell(uname) != u.get("shell", "/bin/bash"):
                return True
            desired_groups = set(u.get("groups", []))
            if desired_groups - self._get_user_groups(uname):
                return True
        return False

    # ------------------------------------------------------------------ #
    #  execute
    # ------------------------------------------------------------------ #

    def execute(self) -> None:
        for u in self.users:
            uname = u["username"]
            password = u["password"]
            shell = u.get("shell", "/bin/bash")
            groups = u.get("groups", [])

            if uname == "root":
                # Only set the root password
                self._set_password("root", password)
                continue

            if self._user_exists(uname):
                # Ensure shell and groups are correct
                Command.execute("usermod", ["-s", shell, uname], run_as_chroot=True)
                for g in groups:
                    Command.execute("gpasswd", ["-a", uname, g], run_as_chroot=True)
            else:
                cmd = ["useradd", "-m", "-s", shell]
                if groups:
                    cmd += ["-G", ",".join(groups)]
                cmd.append(uname)
                Command.execute(cmd[0], cmd[1:], run_as_chroot=True)

            self._set_password(uname, password)

    @staticmethod
    def _set_password(username: str, password: str) -> None:
        """Set a user password inside chroot via chpasswd."""
        import subprocess
        chpasswd_input = f"{username}:{password}\n".encode()
        subprocess.run(
            ["arch-chroot", "/mnt", "chpasswd"],
            input=chpasswd_input,
            check=True,
        )

    def verify(self) -> bool:
        for u in self.users:
            uname = u["username"]
            if uname == "root":
                continue
            if not self._user_exists(uname):
                return False
        return True
