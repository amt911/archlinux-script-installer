"""
DASIK - Arch Linux System Installer Kit

A Python-based tool for automated Arch Linux installation and system configuration.

New in this version:
- Idempotent architecture (NixOS-like)
- Action registry pattern for extensibility
- Safe to execute multiple times with same config
"""

__version__ = "0.2.0"
__author__ = "Andres"

# Export main APIs
from .lib.actions import (
    setup_actions,
    execute_installation,
    ActionsHandler,
    AbstractAction,
    register_action
)

__all__ = [
    'setup_actions',
    'execute_installation',
    'ActionsHandler',
    'AbstractAction',
    'register_action',
]
