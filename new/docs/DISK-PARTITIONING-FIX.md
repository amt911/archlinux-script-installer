# Mejoras en el Sistema de Particionado de Discos

## Problema Resuelto

El sistema de particionado tenía un problema crítico: cuando se configuraba un disco con `wipe_disk: false`, el código seguía destruyendo las particiones existentes porque:

1. Siempre creaba una nueva tabla de particiones, independientemente de si existía una
2. Siempre empezaba a crear particiones desde `1MiB`, machacando las particiones existentes

## Cambios Implementados

### 1. Detección de Tabla de Particiones Existente

Se agregó el método `_has_partition_table()` que verifica si un disco ya tiene una tabla de particiones antes de crear una nueva.

```python
def _has_partition_table(self, device: str) -> bool:
    """Check if device has a partition table."""
    try:
        result = Command.execute("parted", ["-s", device, "print"])
        stdout = result.stdout.decode('utf-8') if isinstance(result.stdout, bytes) else result.stdout
        return "Partition Table:" in stdout or "Tabla de particiones:" in stdout
    except Exception:
        return False
```

### 2. Detección de Particiones Existentes

Se agregó el método `_get_existing_partitions()` que lista todas las particiones existentes en un disco:

```python
def _get_existing_partitions(self, device: str) -> List[Dict[str, str]]:
    """Get existing partitions on the device."""
    # Retorna una lista de diccionarios con: number, start, end, size
```

### 3. Cálculo de Posición Inicial Disponible

Se agregó el método `_get_next_available_start()` que calcula dónde empezar las nuevas particiones:

```python
def _get_next_available_start(self, device: str) -> str:
    """Get the next available start position after existing partitions."""
    existing_partitions = self._get_existing_partitions(device)
    
    if not existing_partitions:
        return "1MiB"  # No hay particiones, empezar al principio
    
    # Encontrar la posición final de la última partición
    # Retornar esa posición como inicio para las nuevas particiones
```

### 4. Modificación del Flujo de Procesamiento

El método `_process_disk()` ahora:

```python
def _process_disk(self, disk: DiskLayout) -> None:
    # ...
    
    if disk.wipe_disk:
        self._wipe_disk(disk.device)
        # Solo crear tabla de particiones después de limpiar
        self._create_partition_table(disk.device, disk.partition_table.value)
    else:
        # Solo crear tabla si no existe
        if not self._has_partition_table(disk.device):
            print(f"No partition table found on {disk.device}, creating one...")
            self._create_partition_table(disk.device, disk.partition_table.value)
        else:
            print(f"Using existing partition table on {disk.device}")
    
    # ...
```

### 5. Creación Inteligente de Particiones

El método `_create_partitions()` ahora:

1. Detecta las particiones existentes
2. Calcula el siguiente número de partición disponible
3. Obtiene la posición de inicio después de las particiones existentes
4. Crea las nuevas particiones al final

```python
def _create_partitions(self, disk: DiskLayout) -> None:
    existing_partitions = self._get_existing_partitions(disk.device)
    
    # Determinar siguiente número de partición
    if existing_partitions:
        last_partition_num = max(int(p['number']) for p in existing_partitions)
        partition_number = last_partition_num + 1
        print(f"Found {len(existing_partitions)} existing partition(s), starting from partition {partition_number}")
    else:
        partition_number = 1
        print("No existing partitions found, starting from partition 1")
    
    # Obtener posición de inicio
    start = self._get_next_available_start(disk.device)
    print(f"Starting new partitions at {start}")
    
    # Crear particiones...
```

## Comportamiento Actual

### Con `wipe_disk: true`
1. Se limpian completamente todas las particiones existentes
2. Se crea una nueva tabla de particiones
3. Se crean las particiones declaradas desde el inicio del disco

### Con `wipe_disk: false`
1. Se respetan las particiones existentes
2. Se verifica si existe tabla de particiones (solo se crea si no existe)
3. Se detectan las particiones existentes
4. Las nuevas particiones se crean **después** de las existentes
5. Los números de partición continúan desde la última existente

## Ejemplo de Uso

```json
{
    "disks": [
        {
            "device": "/dev/sda",
            "partition_table": "gpt",
            "wipe_disk": false,
            "partitions": [
                {
                    "label": "home",
                    "size": "50GiB",
                    "filesystem": "ext4",
                    "partition_type": "linux",
                    "mountpoint": "/home",
                    "format": true
                },
                {
                    "label": "data",
                    "size": "rest",
                    "filesystem": "ext4",
                    "partition_type": "linux",
                    "mountpoint": "/data",
                    "format": true
                }
            ]
        }
    ]
}
```

Si `/dev/sda` ya tiene particiones 1 y 2, las nuevas particiones se crearán como 3 y 4, preservando las existentes.

## Casos de Uso

### Caso 1: Disco Nuevo
- Comportamiento: Crea tabla de particiones y todas las particiones desde el inicio
- Archivo de configuración: `wipe_disk: false` o `wipe_disk: true` (mismo resultado)

### Caso 2: Disco con Particiones - Agregar Más
- Comportamiento: Detecta particiones existentes y agrega las nuevas al final
- Archivo de configuración: `wipe_disk: false`

### Caso 3: Disco con Particiones - Empezar de Cero
- Comportamiento: Limpia todo y crea particiones desde cero
- Archivo de configuración: `wipe_disk: true`

## Mejoras Futuras Sugeridas

1. **Validación de espacio disponible**: Verificar que haya suficiente espacio libre antes de intentar crear particiones
2. **Detección de conflictos**: Avisar si las nuevas particiones entrarían en conflicto con las existentes
3. **Resize de particiones**: Permitir redimensionar particiones existentes
4. **Backup automático**: Opción para crear un backup de la tabla de particiones antes de modificarla
