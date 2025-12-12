# Guía de Migración de Acciones Existentes

Esta guía muestra paso a paso cómo migrar las acciones existentes al nuevo sistema idempotente.

## ✅ Timezone (Ya Migrado)

Ver [timezone_action.py](../dasik/lib/actions/timezone_action.py) como ejemplo de referencia.

## 🔄 Locale Action (Pendiente)

### Patrón de is_needed()

```python
def is_needed(self) -> bool:
    """Verificar si locales necesitan configurarse."""
    
    # 1. Verificar /etc/locale.gen
    locale_gen = Path("/mnt/etc/locale.gen")
    if not locale_gen.exists():
        return True
    
    content = locale_gen.read_text()
    for locale in self.selected_locales:
        # Verificar que cada locale esté descomentado
        if f"{locale}" not in content or content.find(f"#{locale}") != -1:
            return True
    
    # 2. Verificar /etc/locale.conf
    locale_conf = Path("/mnt/etc/locale.conf")
    if not locale_conf.exists():
        return True
    
    conf_content = locale_conf.read_text()
    if f"LANG={self.desired_locale}" not in conf_content:
        return True
    
    # 3. Verificar vconsole.conf
    vconsole = Path("/mnt/etc/vconsole.conf")
    if not vconsole.exists():
        return True
    
    vconsole_content = vconsole.read_text()
    if f"KEYMAP={self.desired_tty_layout}" not in vconsole_content:
        return True
    
    return False
```

## 🌐 Network Action (Pendiente)

### Patrón de is_needed()

```python
def is_needed(self) -> bool:
    """Verificar si configuración de red necesita aplicarse."""
    
    # 1. Verificar hostname
    hostname_file = Path("/mnt/etc/hostname")
    if not hostname_file.exists():
        return True
    
    current_hostname = hostname_file.read_text().strip()
    if current_hostname != self.hostname:
        return True
    
    # 2. Verificar /etc/hosts
    hosts_file = Path("/mnt/etc/hosts")
    if not hosts_file.exists():
        return True
    
    hosts_content = hosts_file.read_text()
    
    # Verificar localhost entries
    if "127.0.0.1\tlocalhost" not in hosts_content:
        return True
    
    if "::1\t\tlocalhost" not in hosts_content:
        return True
    
    # Verificar hostname entry si add_default_hosts es True
    if self.add_default_hosts and f"127.0.1.1\t{self.hostname}" not in hosts_content:
        return True
    
    # 3. Verificar NetworkManager si type == "networkmanager"
    if self.network_type == "networkmanager":
        nm_service = subprocess.run(
            ["systemctl", "is-enabled", "NetworkManager"],
            capture_output=True,
            cwd="/mnt"
        )
        if nm_service.returncode != 0:
            return True
    
    return False
```

## 🔧 Base Install Action (Pendiente)

### Patrón de is_needed()

```python
def is_needed(self) -> bool:
    """Verificar si sistema base necesita instalarse."""
    
    # 1. Verificar si /mnt tiene sistema instalado
    critical_dirs = [
        Path("/mnt/etc"),
        Path("/mnt/usr"),
        Path("/mnt/var"),
        Path("/mnt/boot")
    ]
    
    for dir_path in critical_dirs:
        if not dir_path.exists():
            return True  # Sistema no instalado
    
    # 2. Verificar pacman database
    pacman_db = Path("/mnt/var/lib/pacman/local")
    if not pacman_db.exists() or not list(pacman_db.iterdir()):
        return True  # Sin paquetes instalados
    
    # 3. Verificar paquetes críticos
    critical_packages = ["base", "linux", "linux-firmware"]
    for pkg in critical_packages:
        pkg_dir = list(pacman_db.glob(f"{pkg}-*"))
        if not pkg_dir:
            return True  # Paquete crítico falta
    
    # 4. Verificar microcode si está habilitado
    if self.enable_microcode:
        cpu_vendor = self._detect_cpu_vendor()
        microcode_pkg = f"{cpu_vendor}-ucode"
        
        if not list(pacman_db.glob(f"{microcode_pkg}-*")):
            return True  # Microcode falta
    
    # 5. Verificar fstab
    fstab = Path("/mnt/etc/fstab")
    if not fstab.exists() or fstab.stat().st_size == 0:
        return True  # fstab no generado
    
    # 6. Verificar bootloader
    # (dependiendo de tu configuración)
    
    return False

def _detect_cpu_vendor(self) -> str:
    """Detectar vendor de CPU."""
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("vendor_id"):
                    if "Intel" in line:
                        return "intel"
                    elif "AMD" in line:
                        return "amd"
    except Exception:
        pass
    return "intel"  # Default
```

## 💾 Disk Partition Action (Pendiente)

### Patrón de is_needed()

```python
def is_needed(self) -> bool:
    """Verificar si discos necesitan particionarse."""
    
    # PRECAUCIÓN: Disk partitioning es destructivo!
    # La idempotencia aquí es más complicada
    
    # 1. Verificar si el disco target existe
    target_device = Path(f"/dev/{self.disk_device}")
    if not target_device.exists():
        raise RuntimeError(f"Disk {target_device} does not exist")
    
    # 2. Verificar si ya tiene particiones esperadas
    # Listar particiones existentes
    result = subprocess.run(
        ["lsblk", "-nlo", "NAME,TYPE", str(target_device)],
        capture_output=True,
        text=True
    )
    
    existing_partitions = []
    for line in result.stdout.splitlines():
        name, type_ = line.split()
        if type_ == "part":
            existing_partitions.append(name)
    
    # 3. Comparar con configuración esperada
    expected_count = len(self.partitions)
    
    if len(existing_partitions) != expected_count:
        print(f"  → Partition count mismatch: {len(existing_partitions)} vs {expected_count}")
        return True
    
    # 4. Verificar filesystems de cada partición
    for partition_config in self.partitions:
        label = partition_config["label"]
        expected_fs = partition_config["filesystem"]
        
        # Encontrar device de partición por label
        device = self._find_partition_by_label(label)
        if not device:
            print(f"  → Partition {label} not found")
            return True
        
        # Verificar filesystem
        current_fs = self._get_filesystem_type(device)
        if current_fs != expected_fs:
            print(f"  → Filesystem mismatch for {label}: {current_fs} vs {expected_fs}")
            return True
    
    print(f"  → Disk already partitioned correctly")
    return False

def _find_partition_by_label(self, label: str) -> str | None:
    """Buscar partición por label."""
    result = subprocess.run(
        ["blkid", "-L", label],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return None

def _get_filesystem_type(self, device: str) -> str:
    """Obtener tipo de filesystem."""
    result = subprocess.run(
        ["lsblk", "-nlo", "FSTYPE", device],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()
```

## 📋 Checklist de Migración

Para cada acción:

- [ ] Cambiar constructor: `__init__(self, config: Dict[str, Any], context=None)`
- [ ] Añadir property `name` que retorna string
- [ ] Implementar `is_needed()` que verifica estado actual
- [ ] Mover lógica de `do_action()` a `execute()`
- [ ] Eliminar verificaciones internas de `execute()` (las hace `is_needed()`)
- [ ] Opcional: implementar `verify()` para validación post-ejecución
- [ ] Eliminar métodos deprecated: `_before_check()`, `KEY_NAME`, etc.
- [ ] Si usa context, actualizar para usar `self.context`
- [ ] Probar idempotencia: ejecutar 2 veces debe ser seguro

## 💡 Tips

### Tip 1: Usar try-except en is_needed()

```python
def is_needed(self) -> bool:
    try:
        # Verificaciones que pueden fallar
        if not Path("/etc/config").exists():
            return True
        
        # ... más checks
        
    except Exception as e:
        # Si no podemos verificar, asumimos que necesita ejecutarse
        print(f"  → Cannot verify state: {e}")
        return True
    
    return False
```

### Tip 2: Logging informativo en is_needed()

```python
def is_needed(self) -> bool:
    config_file = Path("/etc/myconfig")
    
    if not config_file.exists():
        print("  → Config file doesn't exist")
        return True
    
    if self._check_content(config_file):
        print("  → Config content differs")
        return True
    
    print("  → Config is already correct")
    return False
```

### Tip 3: Operaciones destructivas

Para operaciones destructivas (como disk partitioning):

```python
def is_needed(self) -> bool:
    # 1. Verificar precondiciones
    if not self._preconditions_met():
        raise RuntimeError("Preconditions not met")
    
    # 2. Verificar si ya está hecho
    if self._already_configured():
        return False
    
    # 3. Si necesita ejecutarse, advertir
    print("  ⚠️  WARNING: This will modify disk partitions!")
    return True
```

### Tip 4: Usar context para compartir estado

```python
# En DiskPartitionAction.execute()
for label, device in self.partition_map.items():
    self.context.set_partition(label, device)

# En BaseInstallAction.is_needed()
root_partition = self.context.get_partition("root")
if root_partition:
    # Verificar si root está montado
    pass
```

## 🧪 Testing Individual

Para probar una acción sin ejecutar todo:

```python
from dasik.lib.actions.timezone_action import TimezoneAction
from dasik.lib.actions.action_context import ActionContext

# Configuración de prueba
config = {
    "region": "Europe",
    "city": "Madrid"
}

# Crear acción
context = ActionContext()
action = TimezoneAction(config, context)

# Probar idempotencia
print("Primera comprobación:")
print(f"  is_needed: {action.is_needed()}")

if action.is_needed():
    action.execute()
    print("  Ejecutado!")

print("\nSegunda comprobación:")
print(f"  is_needed: {action.is_needed()}")
print("  (debería ser False)")
```

---

Con estos patrones, migrar las acciones restantes debería ser directo. El objetivo es que `is_needed()` verifique el **estado actual del sistema** y retorne `True` solo si difiere de la configuración deseada.
