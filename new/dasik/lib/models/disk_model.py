"""Models for disk partitioning configuration."""
from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field, field_validator


class PartitionTableType(str, Enum):
    """Partition table types."""
    GPT = "gpt"
    MSDOS = "msdos"


class FileSystemType(str, Enum):
    """Supported filesystem types."""
    EXT4 = "ext4"
    BTRFS = "btrfs"
    FAT32 = "fat32"
    SWAP = "swap"
    XFS = "xfs"


class PartitionType(str, Enum):
    """Partition types for GPT."""
    EFI = "esp"  # EFI System Partition
    LINUX = "linux"
    SWAP = "linux-swap"
    LVM = "lvm"


class BtrfsSubvolume(BaseModel):
    """Btrfs subvolume configuration."""
    name: str = Field(..., description="Subvolume name (e.g., '@', '@home')")
    mountpoint: str = Field(..., description="Mount point (e.g., '/', '/home')")
    mount_options: List[str] = Field(
        default_factory=lambda: ["compress-force=zstd"],
        description="Mount options for this subvolume"
    )


class Partition(BaseModel):
    """Partition configuration."""
    label: str = Field(..., description="Partition label for identification")
    size: str = Field(
        ...,
        description="Size: number with unit (100MB, 512MiB, 1GB, 1GiB) or percentage (50%) or 'rest' for remaining space"
    )
    filesystem: FileSystemType = Field(..., description="Filesystem type")
    partition_type: PartitionType = Field(
        default=PartitionType.LINUX,
        description="Partition type (GPT)"
    )
    mountpoint: Optional[str] = Field(
        None,
        description="Mount point (e.g., '/', '/boot', '/home')"
    )
    encrypt: bool = Field(
        default=False,
        description="Whether to encrypt this partition with LUKS"
    )
    luks_name: Optional[str] = Field(
        None,
        description="LUKS device mapper name if encrypted"
    )
    mount_options: List[str] = Field(
        default_factory=list,
        description="Additional mount options"
    )
    btrfs_subvolumes: List[BtrfsSubvolume] = Field(
        default_factory=list,
        description="Btrfs subvolumes (only if filesystem is btrfs)"
    )
    format: bool = Field(
        default=True,
        description="Whether to format this partition"
    )

    @field_validator('size')
    @classmethod
    def validate_size(cls, v: str) -> str:
        """Validate size format."""
        v = v.strip()
        if v.lower() == 'rest':
            return v
        
        # Check for percentage
        if v.endswith('%'):
            try:
                percent = int(v[:-1])
                if not 1 <= percent <= 100:
                    raise ValueError("Percentage must be between 1 and 100")
                return v
            except ValueError:
                raise ValueError(f"Invalid percentage format: {v}")
        
        # Check for size with unit
        valid_units = ['B', 'KB', 'MB', 'GB', 'TB', 'KiB', 'MiB', 'GiB', 'TiB']
        has_valid_unit = any(v.upper().endswith(unit.upper()) for unit in valid_units)
        
        if not has_valid_unit:
            raise ValueError(
                f"Size must end with a valid unit: {', '.join(valid_units)} "
                f"or be a percentage (e.g., '50%') or 'rest'"
            )
        
        return v

    @field_validator('luks_name')
    @classmethod
    def validate_luks_name(cls, v: Optional[str], info) -> Optional[str]:
        """Validate that luks_name is set if encrypt is True."""
        values = info.data
        if values.get('encrypt') and not v:
            raise ValueError("luks_name must be set when encrypt is True")
        return v


class DiskLayout(BaseModel):
    """Disk layout configuration."""
    device: str = Field(
        ...,
        description="Device path (e.g., '/dev/sda', '/dev/nvme0n1')",
        examples=["/dev/sda", "/dev/nvme0n1", "/dev/vda"]
    )
    partition_table: PartitionTableType = Field(
        default=PartitionTableType.GPT,
        description="Partition table type"
    )
    wipe_disk: bool = Field(
        default=False,
        description="Whether to wipe the entire disk before partitioning (DESTRUCTIVE!)"
    )
    partitions: List[Partition] = Field(
        ...,
        description="List of partitions to create",
        min_length=1
    )

    @field_validator('device')
    @classmethod
    def validate_device(cls, v: str) -> str:
        """Validate device path format."""
        if not v.startswith('/dev/'):
            raise ValueError("Device must start with '/dev/'")
        return v

    @field_validator('partitions')
    @classmethod
    def validate_partitions(cls, v: List[Partition]) -> List[Partition]:
        """Validate partitions list."""
        # Check that only one partition has 'rest' size
        rest_count = sum(1 for p in v if p.size.lower() == 'rest')
        if rest_count > 1:
            raise ValueError("Only one partition can have size 'rest'")
        
        # If there's a 'rest' partition, it should be the last one
        if rest_count == 1:
            rest_index = next(i for i, p in enumerate(v) if p.size.lower() == 'rest')
            if rest_index != len(v) - 1:
                raise ValueError("Partition with size 'rest' must be the last partition")
        
        # Check for duplicate labels
        labels = [p.label for p in v]
        if len(labels) != len(set(labels)):
            raise ValueError("Partition labels must be unique")
        
        # Validate btrfs subvolumes only for btrfs filesystems
        for partition in v:
            if partition.btrfs_subvolumes and partition.filesystem != FileSystemType.BTRFS:
                raise ValueError(
                    f"Partition '{partition.label}' has btrfs_subvolumes but filesystem is not btrfs"
                )
        
        return v


class DisksConfiguration(BaseModel):
    """Root configuration for disk layouts."""
    disks: List[DiskLayout] = Field(
        ...,
        description="List of disk layouts to configure",
        min_length=1
    )
