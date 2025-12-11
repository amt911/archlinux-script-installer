# Sistema de Particionado Declarativo - Resumen

## 📋 ¿Qué se ha creado?

### 1. **Modelos de Datos** (`dasik/lib/models/disk_model.py`)
- `DisksConfiguration`: Configuración raíz
- `DiskLayout`: Layout de un disco
- `Partition`: Definición de partición individual
- `BtrfsSubvolume`: Subvolúmenes BTRFS
- Enums: `FileSystemType`, `PartitionType`, `PartitionTableType`

**Validación automática con Pydantic:**
- Tamaños válidos (MB, GB, %, rest)
- Solo una partición con `size: "rest"`
- Labels únicos
- LUKS name requerido si encrypt=true
- Subvolúmenes solo para BTRFS

### 2. **Acción de Particionado** (`dasik/lib/actions/disk_partition_action.py`)

**Funcionalidades:**
- ✅ Crear tabla de particiones (GPT/MSDOS)
- ✅ Crear particiones con `parted`
- ✅ Detectar nombres de dispositivo (sda, nvme, mmcblk)
- ✅ Formatear particiones (ext4, btrfs, fat32, swap, xfs)
- ✅ Encriptación LUKS
- ✅ Subvolúmenes BTRFS
- ✅ Montaje automático en orden correcto
- ✅ Mapeo label → device path

**Métodos clave:**
```python
action = DiskPartitionAction(config)
action.run()  # Ejecuta todo el proceso

# Obtener dispositivos creados
root_dev = action.get_partition_device("root")
all_partitions = action.get_all_partitions()
```

### 3. **Ejemplos de Configuración**

#### `/config/disk-example.json`
Setup completo con encriptación y BTRFS

#### `/config/disk-simple-ext4.json`
Setup simple EXT4 sin encriptación

#### `/examples/disk_partitioning_example.py`
Script Python con ejemplos de uso

### 4. **Documentación**

#### `/docs/disk-partitioning.md`
Referencia técnica completa

#### `/docs/DISK-PARTITIONING-EXPLAINED.md`
Explicación detallada en español del sistema

## 🎯 Solución al Problema Original

### Antes (cfdisk manual)
```bash
cfdisk /dev/sda  # Manual, no reproducible
echo "Type boot partition: "
read boot_part   # ¿Cuál es el nombre? No lo sabemos hasta después
```

### Ahora (declarativo)
```json
{
    "partitions": [
        {"label": "boot", "size": "512MiB", "filesystem": "fat32"}
    ]
}
```

```python
action.run()
boot_device = action.get_partition_device("boot")  # ← Sabemos exactamente el nombre
# boot_device = "/dev/sda1" o "/dev/nvme0n1p1" según el disco
```

## 🔑 Características Clave

### 1. **Mapeo Automático de Particiones**
```python
self.partition_map = {
    "boot": "/dev/sda1",
    "swap": "/dev/sda2",
    "root": "/dev/mapper/cryptroot"  # Si está encriptada
}
```

### 2. **Manejo de Diferentes Discos**
- SATA/SCSI: `/dev/sda1`, `/dev/sda2`
- NVMe: `/dev/nvme0n1p1`, `/dev/nvme0n1p2`
- MMC: `/dev/mmcblk0p1`, `/dev/mmcblk0p2`

### 3. **Tamaños Flexibles**
- Absoluto: `"512MiB"`, `"100GB"`
- Porcentaje: `"50%"`
- Resto: `"rest"` (debe ser última partición)

### 4. **Particiones Existentes**
```json
{
    "wipe_disk": false,  // No borra el disco
    "partitions": [
        {
            "label": "data",
            "format": false  // No formatea, usa partición existente
        }
    ]
}
```

## 🚀 Casos de Uso

### Instalación Limpia Torre AMD (como tu script)
```json
{
    "device": "/dev/nvme0n1",
    "wipe_disk": true,
    "partitions": [
        {"label": "boot", "size": "512MiB", "filesystem": "fat32"},
        {"label": "swap", "size": "32GiB", "filesystem": "swap"},
        {
            "label": "root",
            "size": "rest",
            "filesystem": "btrfs",
            "encrypt": true,
            "luks_name": "cryptroot",
            "btrfs_subvolumes": [
                {"name": "@", "mountpoint": "/"},
                {"name": "@home", "mountpoint": "/home"},
                {"name": "@var_cache", "mountpoint": "/var/cache"}
            ]
        }
    ]
}
```

### Laptop Simple EXT4
```json
{
    "device": "/dev/sda",
    "wipe_disk": true,
    "partitions": [
        {"label": "EFI", "size": "512MiB", "filesystem": "fat32"},
        {"label": "swap", "size": "8GiB", "filesystem": "swap"},
        {"label": "root", "size": "rest", "filesystem": "ext4"}
    ]
}
```

### Añadir Partición de Datos
```json
{
    "device": "/dev/sdb",
    "wipe_disk": false,
    "partitions": [
        {"label": "data", "size": "rest", "filesystem": "ext4"}
    ]
}
```

## 📦 Dependencias

Ya añadida en `pyproject.toml`:
```toml
dependencies = [
    "colorama",
    "pydantic"  # ← Para validación de modelos
]
```

## ⚙️ Integración con ActionsHandler

```python
from dasik.lib.models.disk_model import DisksConfiguration
from dasik.lib.actions.disk_partition_action import DiskPartitionAction

# En tu configuration JSON principal
{
    "disks": { ... },  # ← Configuración de discos
    "timezone": { ... },
    "locale": { ... }
}

# En ActionsHandler
def handle_disks(self, disk_config):
    config = DisksConfiguration(**disk_config)
    action = DiskPartitionAction(config)
    action.run()
    
    # Guardar para siguientes pasos
    self.partition_map = action.get_all_partitions()
```

## 🧪 Probar el Sistema

```bash
# Ver ejemplos (sin ejecutar nada)
cd /home/andres/repos/archlinux-script-installer/new
python examples/disk_partitioning_example.py

# Validar un archivo de configuración
python -c "
import json
from dasik.lib.models.disk_model import DisksConfiguration

with open('config/disk-example.json') as f:
    config = DisksConfiguration(**json.load(f))
    
print('✅ Configuración válida!')
print(f'Discos: {len(config.disks)}')
"
```

## ✅ Próximos Pasos Sugeridos

1. **Integrar con ActionsHandler**
   - Añadir soporte en `actions_handler.py`
   - Leer sección "disks" del JSON principal

2. **Añadir modo dry-run**
   - Mostrar qué se haría sin ejecutar
   - Útil para testing

3. **Pre-flight checks**
   - Verificar espacio disponible
   - Comprobar que herramientas existen

4. **Manejo de errores robusto**
   - Rollback si algo falla
   - Logs detallados

5. **Testing**
   - Unit tests para validación
   - Integration tests en VM

## 📚 Archivos Creados

```
new/
├── dasik/lib/models/
│   ├── __init__.py          (actualizado)
│   └── disk_model.py        (NUEVO)
├── dasik/lib/actions/
│   └── disk_partition_action.py  (NUEVO)
├── config/
│   ├── disk-example.json           (NUEVO)
│   └── disk-simple-ext4.json       (NUEVO)
├── examples/
│   └── disk_partitioning_example.py  (NUEVO)
└── docs/
    ├── disk-partitioning.md          (NUEVO)
    └── DISK-PARTITIONING-EXPLAINED.md (NUEVO)
```

## 🎓 Conceptos Clave

1. **Declarativo vs Imperativo**: Defines "qué quieres", no "cómo hacerlo"
2. **Validación temprana**: Errores detectados antes de tocar el disco
3. **Reproducibilidad**: Mismo JSON = Mismo resultado
4. **Trazabilidad**: Sabes exactamente qué dispositivo es cada partición
5. **Modularidad**: Fácil de extender con nuevos filesystems o features

---

**¿Dudas o necesitas más ejemplos?** Los archivos de documentación tienen más detalles y casos de uso.
