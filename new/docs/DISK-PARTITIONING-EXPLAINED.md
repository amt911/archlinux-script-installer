# Sistema de Particionado Declarativo

## Problema Resuelto

Antes: Usabas `cfdisk` manualmente y preguntabas por las particiones de forma interactiva, sin saber exactamente qué nombres de dispositivo tendrían las particiones creadas.

Ahora: Defines todo en un JSON y el sistema:
1. ✅ Crea las particiones automáticamente
2. ✅ Sabe exactamente qué nombre tiene cada partición (mapea label → device)
3. ✅ Maneja diferentes esquemas de nombrado (sda, nvme, mmcblk)
4. ✅ Puede trabajar con particiones existentes (`wipe_disk: false`)
5. ✅ Soporta encriptación LUKS
6. ✅ Soporta subvolúmenes BTRFS

## Ventajas Clave

### 1. Reproducibilidad
Tu configuración es un archivo JSON que puedes versionar, compartir y reutilizar.

### 2. Seguridad
Validación completa antes de ejecutar nada. Si el JSON está mal, lo sabrás antes de tocar el disco.

### 3. Flexibilidad
```json
"size": "512MiB"    // Tamaño fijo
"size": "50%"        // Porcentaje del disco
"size": "rest"       // Todo el espacio restante
```

### 4. Mapeo Automático de Particiones

El código internamente mantiene un diccionario:
```python
{
    "EFI": "/dev/sda1",
    "swap": "/dev/sda2",
    "root": "/dev/mapper/cryptroot"  # Si está encriptada
}
```

Después de particionar, puedes obtener el dispositivo:
```python
action = DiskPartitionAction(config)
action.run()

# Ahora sabes exactamente dónde está cada partición
efi_dev = action.get_partition_device("EFI")      # "/dev/sda1"
root_dev = action.get_partition_device("root")    # "/dev/sda2" o "/dev/mapper/cryptroot"
```

## Cómo Funciona el Descubrimiento de Particiones

### Paso 1: Crear Partición
```python
# El código calcula: /dev/sda + número de partición
def _get_partition_device(device: str, partition_number: int) -> str:
    # NVMe/MMC usan 'p': /dev/nvme0n1p1
    if 'nvme' in device or 'mmcblk' in device:
        return f"{device}p{partition_number}"
    # SATA/SCSI: /dev/sda1
    else:
        return f"{device}{partition_number}"
```

### Paso 2: Guardar en Mapa
```python
self.partition_map[partition.label] = "/dev/sda1"
```

### Paso 3: Si Hay Encriptación
```python
if partition.encrypt:
    # Encripta /dev/sda2
    # Abre como /dev/mapper/cryptroot
    # Actualiza el mapa
    self.partition_map["root"] = "/dev/mapper/cryptroot"
```

## Ejemplos de Uso

### Caso 1: Instalación Limpia (Torre AMD - como tu script antiguo)

```json
{
    "disks": [{
        "device": "/dev/nvme0n1",
        "partition_table": "gpt",
        "wipe_disk": true,
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
                "size": "32GiB",
                "filesystem": "swap"
            },
            {
                "label": "root",
                "size": "rest",
                "filesystem": "btrfs",
                "mountpoint": "/",
                "encrypt": true,
                "luks_name": "cryptroot",
                "btrfs_subvolumes": [
                    {"name": "@", "mountpoint": "/"},
                    {"name": "@home", "mountpoint": "/home"},
                    {"name": "@var_cache", "mountpoint": "/var/cache"},
                    {"name": "@var_log", "mountpoint": "/var/log"},
                    {"name": "@srv", "mountpoint": "/srv"},
                    {"name": "@var_tmp", "mountpoint": "/var/tmp"}
                ]
            }
        ]
    }]
}
```

### Caso 2: Añadir Partición a Disco Existente

```json
{
    "disks": [{
        "device": "/dev/sdb",
        "partition_table": "gpt",
        "wipe_disk": false,  // ← Importante: no borra el disco
        "partitions": [
            {
                "label": "data",
                "size": "rest",
                "filesystem": "ext4",
                "mountpoint": "/mnt/data"
            }
        ]
    }]
}
```

### Caso 3: Laptop Simple (EXT4 sin encriptación)

```json
{
    "disks": [{
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
                "filesystem": "swap"
            },
            {
                "label": "root",
                "size": "rest",
                "filesystem": "ext4",
                "mountpoint": "/",
                "mount_options": ["noatime"]
            }
        ]
    }]
}
```

## Integración con el Sistema

```python
# En tu actions_handler.py o similar
import json
from dasik.lib.models.disk_model import DisksConfiguration
from dasik.lib.actions.disk_partition_action import DiskPartitionAction

def handle_disk_partitioning(config_file: str):
    # Cargar configuración
    with open(config_file) as f:
        disk_config = json.load(f)
    
    # Validar y parsear (Pydantic valida automáticamente)
    config = DisksConfiguration(**disk_config)
    
    # Ejecutar particionado
    action = DiskPartitionAction(config)
    action.run()
    
    # Ahora puedes obtener los dispositivos para siguientes pasos
    partitions = action.get_all_partitions()
    
    # Ejemplo: pasar root_partition a siguiente paso
    root_dev = action.get_partition_device("root")
    boot_dev = action.get_partition_device("boot")
    
    return {
        "root_device": root_dev,
        "boot_device": boot_dev,
        "all_partitions": partitions
    }
```

## Comparación con Script Antiguo

### Antes (installer-1.sh)
```bash
# 1. Abrir cfdisk manualmente
cfdisk "$part"

# 2. Preguntar por cada partición
echo -ne "Type the boot partition: "
read -r boot_part
echo -ne "Type the root partition: "
read -r root_part
echo -ne "Type the swap partition: "
read -r swap_part

# 3. No hay validación
# 4. No hay forma de reproducir
# 5. Propenso a errores humanos
```

### Ahora (disk_model.py + disk_partition_action.py)
```json
{
    "partitions": [
        {"label": "boot", "size": "512MiB", ...},
        {"label": "root", "size": "rest", ...},
        {"label": "swap", "size": "8GiB", ...}
    ]
}
```

✅ Declarativo
✅ Validado
✅ Reproducible
✅ Versionable
✅ Sin intervención manual

## Próximos Pasos

1. **Integrar con ActionsHandler**: Añadir `disk_partition_action` al handler principal
2. **Añadir dry-run**: Mostrar qué se haría sin ejecutar
3. **Añadir verificación pre-vuelo**: Comprobar espacio disponible, etc.
4. **Manejo de errores**: Rollback si algo falla
5. **Logs detallados**: Registrar cada paso para debugging

## Herramientas Requeridas

El sistema usa estas herramientas estándar de Linux:
- `parted` - Particionado scriptable
- `mkfs.ext4`, `mkfs.btrfs`, `mkfs.fat`, `mkfs.xfs` - Formateo
- `cryptsetup` - Encriptación LUKS
- `btrfs` - Gestión de subvolúmenes
- `mount`, `umount` - Montaje
- `lsblk`, `partprobe`, `blockdev` - Detección de particiones

Todas estas herramientas están disponibles en el entorno live de Arch Linux.
