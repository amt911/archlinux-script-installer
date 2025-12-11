# Disk Partitioning Configuration

## Overview

The disk partitioning system allows you to declaratively define how your disks should be partitioned and formatted. This replaces the old manual `cfdisk` approach with a reproducible, scriptable configuration.

## How It Works

### Partition Discovery

After partitions are created, the system automatically tracks them using a mapping system:

```python
self.partition_map = {
    "EFI": "/dev/sda1",
    "swap": "/dev/sda2", 
    "root": "/dev/mapper/cryptroot"  # If encrypted
}
```

The system handles different disk naming schemes:
- SATA/SCSI: `/dev/sda1`, `/dev/sda2`, ...
- NVMe: `/dev/nvme0n1p1`, `/dev/nvme0n1p2`, ...
- MMC: `/dev/mmcblk0p1`, `/dev/mmcblk0p2`, ...

### Partition Sizes

You can specify sizes in multiple ways:

- **Absolute sizes**: `"512MiB"`, `"8GiB"`, `"100GB"`
- **Percentages**: `"50%"` (50% of disk)
- **Rest of disk**: `"rest"` (use remaining space - must be last partition)

## Configuration Examples

### Simple EXT4 Setup

```json
{
    "disks": [
        {
            "device": "/dev/sda",
            "partition_table": "gpt",
            "wipe_disk": true,
            "partitions": [
                {
                    "label": "EFI",
                    "size": "512MiB",
                    "filesystem": "fat32",
                    "partition_type": "esp",
                    "mountpoint": "/boot"
                },
                {
                    "label": "root",
                    "size": "rest",
                    "filesystem": "ext4",
                    "mountpoint": "/"
                }
            ]
        }
    ]
}
```

### With Swap Partition

```json
{
    "disks": [
        {
            "device": "/dev/sda",
            "partition_table": "gpt",
            "wipe_disk": true,
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
                    "mountpoint": "/"
                }
            ]
        }
    ]
}
```

### Encrypted Root with BTRFS Subvolumes

```json
{
    "disks": [
        {
            "device": "/dev/nvme0n1",
            "partition_table": "gpt",
            "wipe_disk": true,
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
                    "size": "16GiB",
                    "filesystem": "swap",
                    "partition_type": "linux-swap"
                },
                {
                    "label": "root",
                    "size": "rest",
                    "filesystem": "btrfs",
                    "partition_type": "linux",
                    "mountpoint": "/",
                    "encrypt": true,
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
                            "mount_options": ["compress-force=zstd", "noatime"]
                        },
                        {
                            "name": "@var_log",
                            "mountpoint": "/var/log",
                            "mount_options": ["compress-force=zstd"]
                        },
                        {
                            "name": "@srv",
                            "mountpoint": "/srv",
                            "mount_options": ["compress-force=zstd"]
                        },
                        {
                            "name": "@var_tmp",
                            "mountpoint": "/var/tmp",
                            "mount_options": ["compress-force=zstd"]
                        }
                    ]
                }
            ]
        }
    ]
}
```

### Dual Boot Setup (Preserving Existing Partitions)

```json
{
    "disks": [
        {
            "device": "/dev/sda",
            "partition_table": "gpt",
            "wipe_disk": false,
            "partitions": [
                {
                    "label": "linux-root",
                    "size": "100GiB",
                    "filesystem": "ext4",
                    "mountpoint": "/",
                    "format": true
                },
                {
                    "label": "linux-home",
                    "size": "rest",
                    "filesystem": "ext4",
                    "mountpoint": "/home",
                    "format": true
                }
            ]
        }
    ]
}
```

Note: In this case, you would need to manually ensure the EFI partition already exists and mount it separately, or add it to the configuration with `"format": false`.

## Usage in Code

```python
from dasik.lib.models.disk_model import DisksConfiguration
from dasik.lib.actions.disk_partition_action import DiskPartitionAction

# Load configuration
with open('disk-config.json') as f:
    config_data = json.load(f)

# Parse and validate
config = DisksConfiguration(**config_data)

# Create and run action
action = DiskPartitionAction(config)
action.run()

# Get partition information after creation
efi_partition = action.get_partition_device("EFI")
root_partition = action.get_partition_device("root")

print(f"EFI partition: {efi_partition}")
print(f"Root partition: {root_partition}")

# Get all partitions
all_partitions = action.get_all_partitions()
for label, device in all_partitions.items():
    print(f"{label}: {device}")
```

## Partition Options Reference

### Required Fields

- `label`: Unique identifier for the partition
- `size`: Size specification (see sizes section)
- `filesystem`: Filesystem type (`ext4`, `btrfs`, `fat32`, `swap`, `xfs`)

### Optional Fields

- `partition_type`: GPT partition type (`esp`, `linux`, `linux-swap`, `lvm`) - default: `linux`
- `mountpoint`: Where to mount the partition (e.g., `/`, `/boot`, `/home`)
- `encrypt`: Enable LUKS encryption - default: `false`
- `luks_name`: Device mapper name for encrypted partition (required if `encrypt: true`)
- `mount_options`: List of mount options (e.g., `["noatime", "compress=zstd"]`)
- `btrfs_subvolumes`: List of subvolumes (only for btrfs)
- `format`: Whether to format the partition - default: `true`

## Tools Used

The system uses these standard Linux tools:
- `parted` - Create partitions
- `mkfs.*` - Format filesystems
- `cryptsetup` - LUKS encryption
- `btrfs` - Manage btrfs subvolumes
- `mount` - Mount filesystems
- `lsblk`, `partprobe` - Partition discovery

## Safety Features

1. **Validation**: Pydantic models validate configuration before execution
2. **Dry-run support**: Can be added to preview changes
3. **Partition tracking**: Automatically maps labels to device paths
4. **Existing partition handling**: `wipe_disk: false` allows working with existing partitions
5. **Mount ordering**: Partitions mounted in correct order (root before subdirectories)
