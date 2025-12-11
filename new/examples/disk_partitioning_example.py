#!/usr/bin/env python3
"""
Example script demonstrating disk partitioning usage.

This shows how to use the disk partitioning system.
"""

import json
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from dasik.lib.models.disk_model import DisksConfiguration
from dasik.lib.actions.disk_partition_action import DiskPartitionAction


def example_simple_ext4():
    """Example: Simple EXT4 setup."""
    config_data = {
        "disks": [
            {
                "device": "/dev/sda",
                "partition_table": "gpt",
                "wipe_disk": True,
                "partitions": [
                    {
                        "label": "EFI",
                        "size": "512MiB",
                        "filesystem": "fat32",
                        "partition_type": "esp",
                        "mountpoint": "/boot"
                    },
                    {
                        "label": "swap",
                        "size": "8GiB",
                        "filesystem": "swap",
                        "partition_type": "linux-swap"
                    },
                    {
                        "label": "root",
                        "size": "rest",
                        "filesystem": "ext4",
                        "mountpoint": "/",
                        "mount_options": ["noatime"]
                    }
                ]
            }
        ]
    }
    
    # Parse and validate
    config = DisksConfiguration(**config_data)
    
    # Create action
    action = DiskPartitionAction(config)
    
    # Run (commented out for safety)
    # action.run()
    
    # Show what we would create
    print("Would create the following partitions:")
    for partition in config.disks[0].partitions:
        print(f"  - {partition.label}: {partition.size} ({partition.filesystem.value})")
    
    return action


def example_encrypted_btrfs():
    """Example: Encrypted BTRFS with subvolumes."""
    config_data = {
        "disks": [
            {
                "device": "/dev/nvme0n1",
                "partition_table": "gpt",
                "wipe_disk": True,
                "partitions": [
                    {
                        "label": "boot",
                        "size": "512MiB",
                        "filesystem": "fat32",
                        "partition_type": "esp",
                        "mountpoint": "/boot"
                    },
                    {
                        "label": "swap",
                        "size": "16GiB",
                        "filesystem": "swap",
                        "partition_type": "linux-swap"
                    },
                    {
                        "label": "root",
                        "size": "rest",
                        "filesystem": "btrfs",
                        "mountpoint": "/",
                        "encrypt": True,
                        "luks_name": "cryptroot",
                        "btrfs_subvolumes": [
                            {
                                "name": "@",
                                "mountpoint": "/",
                                "mount_options": ["compress-force=zstd", "noatime"]
                            },
                            {
                                "name": "@home",
                                "mountpoint": "/home",
                                "mount_options": ["compress-force=zstd"]
                            },
                            {
                                "name": "@var_cache",
                                "mountpoint": "/var/cache",
                                "mount_options": ["compress-force=zstd"]
                            },
                            {
                                "name": "@var_log",
                                "mountpoint": "/var/log",
                                "mount_options": ["compress-force=zstd"]
                            }
                        ]
                    }
                ]
            }
        ]
    }
    
    # Parse and validate
    config = DisksConfiguration(**config_data)
    
    print("Would create encrypted BTRFS setup:")
    for partition in config.disks[0].partitions:
        print(f"\n  Partition: {partition.label}")
        print(f"    Size: {partition.size}")
        print(f"    Filesystem: {partition.filesystem.value}")
        if partition.encrypt:
            print(f"    Encrypted: Yes (as {partition.luks_name})")
        if partition.btrfs_subvolumes:
            print(f"    Subvolumes:")
            for subvol in partition.btrfs_subvolumes:
                print(f"      - {subvol.name} → {subvol.mountpoint}")


def example_load_from_file():
    """Example: Load configuration from JSON file."""
    config_file = Path(__file__).parent.parent / "config" / "disk-example.json"
    
    if not config_file.exists():
        print(f"Config file not found: {config_file}")
        return
    
    # Load from file
    with open(config_file) as f:
        config_data = json.load(f)
    
    # Parse and validate
    config = DisksConfiguration(**config_data)
    
    print(f"Loaded configuration from {config_file}")
    print(f"Number of disks: {len(config.disks)}")
    
    for i, disk in enumerate(config.disks, 1):
        print(f"\nDisk {i}: {disk.device}")
        print(f"  Partition table: {disk.partition_table.value}")
        print(f"  Wipe disk: {disk.wipe_disk}")
        print(f"  Partitions:")
        
        for partition in disk.partitions:
            print(f"    - {partition.label}: {partition.size} ({partition.filesystem.value})")
            if partition.mountpoint:
                print(f"      Mount: {partition.mountpoint}")
            if partition.encrypt:
                print(f"      Encrypted: {partition.luks_name}")


def main():
    """Run examples."""
    print("=" * 60)
    print("Disk Partitioning Examples")
    print("=" * 60)
    
    print("\n1. Simple EXT4 Setup")
    print("-" * 60)
    example_simple_ext4()
    
    print("\n\n2. Encrypted BTRFS with Subvolumes")
    print("-" * 60)
    example_encrypted_btrfs()
    
    print("\n\n3. Load from Configuration File")
    print("-" * 60)
    example_load_from_file()
    
    print("\n" + "=" * 60)
    print("Note: Actual partition creation is commented out for safety.")
    print("Uncomment action.run() to execute partitioning.")
    print("=" * 60)


if __name__ == "__main__":
    main()
