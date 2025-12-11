"""Disk partitioning action."""
from pathlib import Path
from typing import Dict, List, Optional
from dasik.lib.actions.abstract_action import AbstractAction
from dasik.lib.models.disk_model import (
    DisksConfiguration,
    DiskLayout,
    Partition,
    FileSystemType,
    BtrfsSubvolume
)
from dasik.lib.command_worker.command_worker import Command


class DiskPartitionAction(AbstractAction):
    """Action to handle disk partitioning in a declarative way."""

    @property
    def KEY_NAME(self) -> str:
        """Return the key name for this action."""
        return "disks"

    def __init__(self, disks_config: DisksConfiguration):
        """Initialize the disk partition action.
        
        Args:
            disks_config: Disk configuration from JSON
        """
        self.disks_config = disks_config
        self.partition_map: Dict[str, str] = {}  # Maps partition label to device path

    @property
    def can_incrementally_change(self) -> bool:
        """Disk partitioning cannot be done incrementally."""
        return False

    def _before_check(self) -> bool:
        """Check if disk partitioning needs to be done.
        
        Returns:
            True if disks are configured
        """
        return len(self.disks_config.disks) > 0

    def after_check(self) -> None:
        """Post-action checks."""
        # Verify all partitions were created
        print("\nVerifying created partitions...")
        for label, device in self.partition_map.items():
            if Path(device).exists():
                print(f"  ✓ {label}: {device}")
            else:
                print(f"  ✗ {label}: {device} (NOT FOUND)")

    def do_action(self) -> None:
        """Execute the disk partitioning action (compatibility method)."""
        if self._before_check():
            self.run()
            self.after_check()
        else:
            print("No disks configured, skipping partitioning.")

    def run(self) -> None:
        """Execute the disk partitioning process."""
        print("Starting disk partitioning process...")
        
        for disk in self.disks_config.disks:
            print(f"\nProcessing disk: {disk.device}")
            self._process_disk(disk)
        
        print("\nDisk partitioning completed successfully!")

    def _process_disk(self, disk: DiskLayout) -> None:
        """Process a single disk layout.
        
        Args:
            disk: Disk layout configuration
        """
        # Check if device exists
        if not Path(disk.device).exists():
            raise FileNotFoundError(f"Device {disk.device} does not exist")
        
        # Show current partition layout
        self._show_current_layout(disk.device)
        
        # Wipe disk if requested
        if disk.wipe_disk:
            self._wipe_disk(disk.device)
            # Create partition table after wiping
            self._create_partition_table(disk.device, disk.partition_table.value)
        else:
            # Only create partition table if it doesn't exist
            if not self._has_partition_table(disk.device):
                print(f"No partition table found on {disk.device}, creating one...")
                self._create_partition_table(disk.device, disk.partition_table.value)
            else:
                print(f"Using existing partition table on {disk.device}")
        
        # Create partitions
        self._create_partitions(disk)
        
        # Refresh partition table
        self._refresh_partition_table(disk.device)
        
        # Format partitions
        for partition in disk.partitions:
            if partition.format:
                self._format_partition(disk.device, partition)
        
        # Mount partitions
        self._mount_partitions(disk)

    def _show_current_layout(self, device: str) -> None:
        """Show current partition layout.
        
        Args:
            device: Device path
        """
        print(f"\nCurrent layout of {device}:")
        try:
            result = Command.execute("lsblk", [device, "-o", "NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT"])
            print(result.stdout)
        except Exception as e:
            print(f"Warning: Could not display current layout: {e}")

    def _has_partition_table(self, device: str) -> bool:
        """Check if device has a partition table.
        
        Args:
            device: Device path
            
        Returns:
            True if device has a partition table
        """
        try:
            result = Command.execute("parted", ["-s", device, "print"])
            # Decode stdout if it's bytes
            stdout = result.stdout.decode('utf-8') if isinstance(result.stdout, bytes) else result.stdout
            # If parted can print the table, it exists
            return "Partition Table:" in stdout or "Tabla de particiones:" in stdout
        except Exception:
            return False

    def _get_existing_partitions(self, device: str) -> List[Dict[str, str]]:
        """Get existing partitions on the device.
        
        Args:
            device: Device path
            
        Returns:
            List of partition info dictionaries with keys: number, start, end, size
        """
        try:
            result = Command.execute("parted", ["-s", device, "unit", "MiB", "print"])
            # Decode stdout if it's bytes
            stdout = result.stdout.decode('utf-8') if isinstance(result.stdout, bytes) else result.stdout
            partitions = []
            
            # Parse parted output
            lines = stdout.split('\n')
            for line in lines:
                # Look for lines that start with a number (partition entries)
                line = line.strip()
                if not line:
                    continue
                
                # Skip lines containing "Free Space" or without proper structure
                if 'Free Space' in line or 'free space' in line.lower():
                    continue
                
                # Check if line starts with a digit
                if line[0].isdigit():
                    parts = line.split()
                    if len(parts) >= 4:
                        # Verify first part is an integer (partition number)
                        try:
                            partition_num = int(parts[0])
                            partitions.append({
                                'number': str(partition_num),
                                'start': parts[1],
                                'end': parts[2],
                                'size': parts[3]
                            })
                        except ValueError:
                            # Not a valid partition number, skip this line
                            continue
            
            return partitions
        except Exception as e:
            print(f"Warning: Could not get existing partitions: {e}")
            return []

    def _get_next_available_start(self, device: str) -> str:
        """Get the next available start position after existing partitions.
        
        Args:
            device: Device path
            
        Returns:
            Start position as string (e.g., "100MiB")
        """
        existing_partitions = self._get_existing_partitions(device)
        
        if not existing_partitions:
            # No existing partitions, start at 1MiB for alignment
            return "1MiB"
        
        print(f"Detected {len(existing_partitions)} existing partition(s):")
        for part in existing_partitions:
            print(f"  Partition {part['number']}: {part['start']} -> {part['end']} (size: {part['size']})")
        
        # Find the maximum end position
        max_end = "1MiB"
        for part in existing_partitions:
            end_str = part.get('end', '0MiB')
            # Extract numeric value
            try:
                end_value = float(end_str.replace('MiB', '').replace('MB', '').replace('GiB', '').replace('GB', ''))
                # Convert to MiB if needed
                if 'GiB' in end_str or 'GB' in end_str:
                    end_value = end_value * 1024
                current_max = float(max_end.replace('MiB', '').replace('MB', ''))
                if end_value > current_max:
                    max_end = f"{end_value}MiB"
            except ValueError:
                continue
        
        # Return the position right after the last partition
        return max_end
    
    def _get_disk_size_mib(self, device: str) -> float:
        """Get the total size of the disk in MiB.
        
        Args:
            device: Device path
            
        Returns:
            Disk size in MiB
        """
        try:
            result = Command.execute("blockdev", ["--getsize64", device])
            stdout_str = result.stdout.decode('utf-8') if isinstance(result.stdout, bytes) else str(result.stdout)
            size_bytes = int(stdout_str.strip())
            size_mib = size_bytes / (1024 * 1024)
            return size_mib
        except Exception:
            # Fallback: try to parse from parted
            try:
                result = Command.execute("parted", ["-s", device, "unit", "MiB", "print"])
                stdout_str = result.stdout.decode('utf-8') if isinstance(result.stdout, bytes) else str(result.stdout)
                for line in stdout_str.split('\n'):
                    if 'Disk' in line and device in line:
                        # Extract size from line like "Disk /dev/vda: 15360MiB"
                        parts = line.split(':')
                        if len(parts) >= 2:
                            size_str = parts[1].strip().split()[0]
                            return float(size_str.replace('MiB', '').replace('MB', ''))
            except Exception:
                pass
        
        # If all else fails, return a large number
        return 999999.0

    def _wipe_disk(self, device: str) -> None:
        """Wipe the entire disk.
        
        Args:
            device: Device path
        """
        print(f"Wiping disk {device}...")
        print("WARNING: This will destroy all data on the disk!")
        
        # Wipe first and last few MB of the disk
        Command.execute("wipefs", ["--all", "--force", device])
        Command.execute("sgdisk", ["--zap-all", device])

    def _create_partition_table(self, device: str, table_type: str) -> None:
        """Create a new partition table.
        
        Args:
            device: Device path
            table_type: Partition table type (gpt or msdos)
        """
        print(f"Creating {table_type} partition table on {device}...")
        Command.execute("parted", ["-s", device, "mklabel", table_type])

    def _create_partitions(self, disk: DiskLayout) -> None:
        """Create all partitions on the disk.
        
        Args:
            disk: Disk layout configuration
        """
        print(f"Creating partitions on {disk.device}...")
        
        # Get existing partitions to find the next partition number and start position
        existing_partitions = self._get_existing_partitions(disk.device)
        
        # Determine next partition number
        if existing_partitions:
            last_partition_num = max(int(p['number']) for p in existing_partitions)
            partition_number = last_partition_num + 1
            print(f"Found {len(existing_partitions)} existing partition(s), starting from partition {partition_number}")
        else:
            partition_number = 1
            print("No existing partitions found, starting from partition 1")
        
        # Get starting position and disk size
        start = self._get_next_available_start(disk.device)
        disk_size_mib = self._get_disk_size_mib(disk.device)
        start_value = float(start.replace('MiB', '').replace('MB', '').replace('GiB', '').replace('GB', ''))
        if 'GiB' in start or 'GB' in start:
            start_value = start_value * 1024
        
        # Check if there's enough space
        available_space_mib = disk_size_mib - start_value
        print(f"Starting new partitions at {start}")
        print(f"Available space: {available_space_mib:.1f} MiB ({available_space_mib / 1024:.2f} GiB)")
        
        if available_space_mib < 100:  # Less than 100 MiB available
            raise RuntimeError(
                f"Not enough space available on {disk.device}. "
                f"Only {available_space_mib:.1f} MiB available after existing partitions. "
                f"Set 'wipe_disk: true' in your configuration to wipe and recreate the disk."
            )
        
        for partition in disk.partitions:
            end = self._calculate_partition_end(start, partition.size, disk.device)
            
            # Create partition using parted
            cmd = [
                "-s", disk.device,
                "mkpart", "primary"
            ]
            
            # Add filesystem type for parted (different from actual filesystem)
            if partition.filesystem == FileSystemType.FAT32:
                cmd.append("fat32")
            elif partition.filesystem == FileSystemType.SWAP:
                cmd.append("linux-swap")
            else:
                cmd.append("ext4")  # Default for parted
            
            cmd.extend([start, end])
            
            print(f"Creating partition {partition.label}: {start} to {end}")
            Command.execute("parted", cmd)
            
            # Set partition type flags for GPT
            if disk.partition_table.value == "gpt":
                if partition.partition_type.value == "esp":
                    Command.execute("parted", ["-s", disk.device, "set", str(partition_number), "esp", "on"])
                elif partition.partition_type.value == "linux-swap":
                    Command.execute("parted", ["-s", disk.device, "set", str(partition_number), "swap", "on"])
            
            # Store partition device path
            part_device = self._get_partition_device(disk.device, partition_number)
            self.partition_map[partition.label] = part_device
            print(f"Partition {partition.label} created at {part_device}")
            
            start = end
            partition_number += 1

    def _calculate_partition_end(self, start: str, size: str, device: str) -> str:
        """Calculate the end position for a partition.
        
        Args:
            start: Start position (e.g., "100MiB")
            size: Partition size (e.g., "100MiB", "50%", "rest")
            device: Device path
            
        Returns:
            End position string for parted
        """
        if size.lower() == "rest":
            return "100%"
        elif size.endswith("%"):
            return size
        else:
            # For absolute sizes, we need to calculate: start + size = end
            # Parse start value
            start_value = float(start.replace('MiB', '').replace('MB', '').replace('GiB', '').replace('GB', ''))
            start_unit = 'MiB'
            if 'GiB' in start or 'GB' in start:
                start_unit = 'GiB'
                if 'GB' in start:
                    start_value = start_value * 1000 / 1024  # Convert GB to GiB
            
            # Parse size value
            size_value: float = 0.0
            size_unit = 'MiB'
            if 'GiB' in size or 'GB' in size:
                size_value = float(size.replace('GiB', '').replace('GB', ''))
                size_unit = 'GiB'
                if 'GB' in size:
                    size_value = size_value * 1000 / 1024  # Convert GB to GiB
            elif 'MiB' in size or 'MB' in size:
                size_value = float(size.replace('MiB', '').replace('MB', ''))
                size_unit = 'MiB'
                if 'MB' in size:
                    size_value = size_value * 1000 / 1024  # Convert MB to MiB
            
            # Convert everything to the same unit (MiB for consistency)
            if start_unit == 'GiB':
                start_value = start_value * 1024
            if size_unit == 'GiB':
                size_value = size_value * 1024
            
            # Calculate end position
            end_value = start_value + size_value
            
            # Return in the most appropriate unit
            if end_value >= 1024:
                return f"{end_value / 1024:.1f}GiB"
            else:
                return f"{end_value:.1f}MiB"

    def _get_partition_device(self, device: str, partition_number: int) -> str:
        """Get the device path for a specific partition number.
        
        Args:
            device: Base device path (e.g., /dev/sda or /dev/nvme0n1)
            partition_number: Partition number
            
        Returns:
            Full partition device path (e.g., /dev/sda1 or /dev/nvme0n1p1)
        """
        # NVMe and MMC devices use 'p' separator
        if 'nvme' in device or 'mmcblk' in device:
            return f"{device}p{partition_number}"
        else:
            return f"{device}{partition_number}"

    def _refresh_partition_table(self, device: str) -> None:
        """Refresh the kernel's partition table.
        
        Args:
            device: Device path
        """
        print("Refreshing partition table...")
        try:
            Command.execute("partprobe", [device])
        except Exception:
            # If partprobe fails, try alternative
            Command.execute("blockdev", ["--rereadpt", device])

    def _format_partition(self, base_device: str, partition: Partition) -> None:
        """Format a partition with the specified filesystem.
        
        Args:
            base_device: Base device path
            partition: Partition configuration
        """
        part_device = self.partition_map[partition.label]
        
        # Handle encryption first
        if partition.encrypt:
            part_device = self._encrypt_partition(part_device, partition)
        
        print(f"Formatting {partition.label} ({part_device}) as {partition.filesystem.value}...")
        
        if partition.filesystem == FileSystemType.EXT4:
            Command.execute("mkfs.ext4", ["-F", "-L", partition.label, part_device])
        
        elif partition.filesystem == FileSystemType.BTRFS:
            Command.execute("mkfs.btrfs", ["-f", "-L", partition.label, part_device])
            # Create subvolumes if specified
            if partition.btrfs_subvolumes:
                self._create_btrfs_subvolumes(part_device, partition.btrfs_subvolumes)
        
        elif partition.filesystem == FileSystemType.FAT32:
            Command.execute("mkfs.fat", ["-F32", "-n", partition.label, part_device])
        
        elif partition.filesystem == FileSystemType.SWAP:
            Command.execute("mkswap", ["-L", partition.label, part_device])
        
        elif partition.filesystem == FileSystemType.XFS:
            Command.execute("mkfs.xfs", ["-f", "-L", partition.label, part_device])
        
        # Update partition map with encrypted device if applicable
        if partition.encrypt:
            self.partition_map[partition.label] = part_device

    def _encrypt_partition(self, device: str, partition: Partition) -> str:
        """Encrypt a partition using LUKS.
        
        Args:
            device: Partition device path
            partition: Partition configuration
            
        Returns:
            Path to the opened LUKS device (/dev/mapper/...)
        """
        print(f"Encrypting partition {partition.label}...")
        print("NOTE: You will be prompted for the encryption password")
        
        # Format with LUKS
        # Note: In a real scenario, you'd want to handle password input securely
        # For now, this assumes interactive password input
        Command.execute("cryptsetup", [
            "luksFormat",
            "--type", "luks2",
            device
        ])
        
        # Open the encrypted partition
        if partition.luks_name:
            Command.execute("cryptsetup", ["open", device, partition.luks_name])
            return f"/dev/mapper/{partition.luks_name}"
        else:
            raise ValueError(f"luks_name is required for encrypted partition {partition.label}")

    def _create_btrfs_subvolumes(self, device: str, subvolumes: List[BtrfsSubvolume]) -> None:
        """Create btrfs subvolumes.
        
        Args:
            device: Btrfs partition device
            subvolumes: List of subvolume configurations
        """
        # Mount temporarily to create subvolumes
        temp_mount = "/mnt/btrfs_temp"
        Path(temp_mount).mkdir(parents=True, exist_ok=True)
        
        try:
            Command.execute("mount", [device, temp_mount])
            
            for subvol in subvolumes:
                print(f"Creating btrfs subvolume: {subvol.name}")
                subvol_path = f"{temp_mount}/{subvol.name}"
                Command.execute("btrfs", ["subvolume", "create", subvol_path])
            
            Command.execute("umount", [temp_mount])
        finally:
            # Cleanup temp mount point
            try:
                Path(temp_mount).rmdir()
            except Exception:
                pass

    def _mount_partitions(self, disk: DiskLayout) -> None:
        """Mount all partitions according to their configuration.
        
        Args:
            disk: Disk layout configuration
        """
        print("\nMounting partitions...")
        
        # Sort partitions by mountpoint depth (mount root first)
        partitions_to_mount = [
            p for p in disk.partitions 
            if p.mountpoint and p.filesystem != FileSystemType.SWAP
        ]
        partitions_to_mount.sort(key=lambda p: p.mountpoint.count('/') if p.mountpoint else 0)
        
        for partition in partitions_to_mount:
            if partition.filesystem == FileSystemType.BTRFS and partition.btrfs_subvolumes:
                self._mount_btrfs_subvolumes(partition)
            else:
                self._mount_partition(partition)
        
        # Enable swap if present
        for partition in disk.partitions:
            if partition.filesystem == FileSystemType.SWAP:
                device = self.partition_map[partition.label]
                print(f"Enabling swap on {device}")
                Command.execute("swapon", [device])

    def _mount_partition(self, partition: Partition) -> None:
        """Mount a single partition.
        
        Args:
            partition: Partition configuration
        """
        device = self.partition_map[partition.label]
        mountpoint = f"/mnt{partition.mountpoint}"
        
        # Create mountpoint
        Path(mountpoint).mkdir(parents=True, exist_ok=True)
        
        # Build mount command
        mount_cmd = ["mount"]
        if partition.mount_options:
            mount_cmd.extend(["-o", ",".join(partition.mount_options)])
        mount_cmd.extend([device, mountpoint])
        
        print(f"Mounting {partition.label} at {mountpoint}")
        Command.execute("mount", mount_cmd[1:])  # Skip 'mount' as Command adds it

    def _mount_btrfs_subvolumes(self, partition: Partition) -> None:
        """Mount btrfs subvolumes.
        
        Args:
            partition: Partition configuration with subvolumes
        """
        device = self.partition_map[partition.label]
        
        for subvol in partition.btrfs_subvolumes:
            mountpoint = f"/mnt{subvol.mountpoint}"
            Path(mountpoint).mkdir(parents=True, exist_ok=True)
            
            # Build mount options
            options = list(subvol.mount_options)
            options.append(f"subvol={subvol.name}")
            
            mount_cmd = ["mount", "-o", ",".join(options), device, mountpoint]
            
            print(f"Mounting subvolume {subvol.name} at {mountpoint}")
            Command.execute("mount", mount_cmd[1:])

    def get_partition_device(self, label: str) -> Optional[str]:
        """Get the device path for a partition by its label.
        
        Args:
            label: Partition label
            
        Returns:
            Device path or None if not found
        """
        return self.partition_map.get(label)

    def get_all_partitions(self) -> Dict[str, str]:
        """Get all partition mappings.
        
        Returns:
            Dictionary mapping partition labels to device paths
        """
        return self.partition_map.copy()
