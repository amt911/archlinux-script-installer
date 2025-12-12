# 🚀 Nueva Arquitectura Idempotente - Dasik v0.2.0

## ✨ ¿Qué ha cambiado?

Dasik ahora tiene una arquitectura **idempotente** similar a NixOS. Esto significa:

- ✅ **Seguro ejecutar múltiples veces**: El mismo JSON aplicado varias veces no rompe nada
- ✅ **Detecta cambios**: Solo ejecuta lo que realmente necesita cambiar
- ✅ **Fácil de extender**: Añadir nuevas acciones es trivial
- ✅ **Mejor organizado**: Código más limpio y mantenible

## 🎯 Ejemplo Rápido

```bash
# Primera ejecución: Configura todo
sudo python -m dasik config.json
# Output: ✅ Timezone configured
#         ✅ Locale configured
#         ✅ Network configured

# Segunda ejecución: Detecta que ya está OK
sudo python -m dasik config.json
# Output: ℹ️  Timezone already configured
#         ℹ️  Locale already configured
#         ℹ️  Network already configured
#         System already configured - no changes needed

# Modificar config.json (cambiar timezone)
# Tercera ejecución: Solo actualiza lo que cambió
sudo python -m dasik config.json
# Output: ✅ Timezone configured (actualizado)
#         ℹ️  Locale already configured
#         ℹ️  Network already configured
```

## 📁 Estructura

```
dasik/lib/actions/
├── abstract_action.py         # Base para todas las acciones
├── action_context.py          # Contexto compartido entre acciones
├── action_registry.py         # Registro de acciones disponibles
├── action_executor.py         # Motor de ejecución idempotente
├── actions_handler_v2.py      # Nueva API principal
│
├── timezone_action.py         # ✅ Migrado (ejemplo)
├── locale_action.py           # ⏳ Pendiente de migrar
├── network_action.py          # ⏳ Pendiente de migrar
├── base_install_action.py     # ⏳ Pendiente de migrar
└── disk_partition_action.py   # ⏳ Pendiente de migrar
```

## 🔧 Uso

### Opción 1: Nueva API (Recomendado)

```python
from dasik.lib.actions import setup_actions, execute_installation

# Registrar todas las acciones
setup_actions()

# Ejecutar instalación
success = execute_installation("config.json")
if success:
    print("Instalación completada!")
```

### Opción 2: API Legacy (Retrocompatibilidad)

```python
from dasik.lib.actions import ActionsHandler

# Funciona igual que antes, pero usa nueva arquitectura internamente
handler = ActionsHandler("config.json")
```

## 🎨 Añadir Nueva Acción

### 1. Crear la clase

```python
# dasik/lib/actions/hostname_action.py
from typing import Dict, Any
from .abstract_action import AbstractAction
from pathlib import Path

class HostnameAction(AbstractAction):
    def __init__(self, config: Dict[str, Any], context=None):
        super().__init__(config, context)
        self.hostname = config["hostname"]
    
    @property
    def name(self) -> str:
        return "Hostname Configuration"
    
    def is_needed(self) -> bool:
        """Verificar si hostname necesita configurarse."""
        hostname_file = Path("/etc/hostname")
        
        if not hostname_file.exists():
            return True
        
        current = hostname_file.read_text().strip()
        return current != self.hostname
    
    def execute(self) -> None:
        """Configurar hostname."""
        Path("/etc/hostname").write_text(f"{self.hostname}\n")
```

### 2. Registrar en `actions_handler_v2.py`

```python
def setup_actions() -> None:
    # ... otros imports
    from .hostname_action import HostnameAction
    
    # ... otros registros
    
    register_action(
        action_class=HostnameAction,
        config_key='hostname',
        is_optional=False,
        required_fields=['hostname']
    )
```

### 3. Usar en JSON

```json
{
  "hostname": {
    "hostname": "my-archlinux"
  }
}
```

**¡Eso es todo!** 🎉

## 📚 Documentación

- **[RESUMEN-MEJORAS.md](docs/RESUMEN-MEJORAS.md)**: Resumen completo de cambios
- **[IDEMPOTENT-ARCHITECTURE.md](docs/IDEMPOTENT-ARCHITECTURE.md)**: Guía detallada de arquitectura
- **[MIGRATION-GUIDE.md](docs/MIGRATION-GUIDE.md)**: Cómo migrar acciones existentes
- **[ARCHITECTURE-DIAGRAM.md](docs/ARCHITECTURE-DIAGRAM.md)**: Diagramas visuales

## 🧪 Ejemplo de Demo

```bash
# Ejecutar demo interactivo
python new/examples/idempotent_demo.py
```

Este script demuestra:
- Registro de acción personalizada
- Idempotencia en acción
- Detección de cambios
- Actualización selectiva

## 🎯 Estado de Migración

| Acción | Estado | is_needed() | execute() | verify() |
|--------|--------|-------------|-----------|----------|
| **TimezoneAction** | ✅ Completo | ✅ | ✅ | ✅ |
| **LocaleAction** | ⏳ Legacy | ❌ | ✅ | ❌ |
| **NetworkAction** | ⏳ Legacy | ❌ | ✅ | ❌ |
| **BaseInstallAction** | ⏳ Legacy | ❌ | ✅ | ❌ |
| **DiskPartitionAction** | ⏳ Legacy | ❌ | ✅ | ❌ |

**Nota**: Las acciones legacy siguen funcionando pero sin idempotencia. Ver [MIGRATION-GUIDE.md](docs/MIGRATION-GUIDE.md) para migrarlas.

## 💡 Conceptos Clave

### Idempotencia

```python
def is_needed(self) -> bool:
    """
    Pregunta: ¿El sistema está como yo quiero?
    
    Si NO → return True (necesita ejecutarse)
    Si SÍ → return False (skip, ya está bien)
    """
    return not Path("/etc/myconfig").exists()
```

### Shared Context

```python
# En DiskPartitionAction
self.context.set_partition("root", "/dev/sda1")

# En BaseInstallAction
root = self.context.get_partition("root")
```

### Action Registry

```python
register_action(
    action_class=MyAction,
    config_key='my_section',      # Clave en JSON
    is_optional=True,              # ¿Obligatoria?
    required_fields=['field1'],    # Campos requeridos
    depends_on=['hostname']        # Dependencias
)
```

## 🔍 Debugging

### Ver qué se ejecutaría

```python
from dasik.lib.actions import setup_actions, ActionExecutor
from dasik.lib.json_parser import JsonParser

setup_actions()
parser = JsonParser("config.json")
config = parser.debug()

executor = ActionExecutor(config)

# Ver cada acción
for action_meta in executor.registry.get_all_actions():
    print(f"Action: {action_meta['class'].__name__}")
    print(f"  Config key: {action_meta['config_key']}")
    print(f"  Optional: {action_meta['is_optional']}")
```

### Ver estado de acciones

```python
# Después de ejecutar
executor.execute_all()

print(f"Ejecutadas: {len([r for r in executor.results if r.status == 'success'])}")
print(f"Ya configuradas: {len([r for r in executor.results if r.status == 'not_needed'])}")
print(f"Skipped: {len([r for r in executor.results if r.status == 'skipped'])}")
print(f"Fallidas: {len([r for r in executor.results if r.status == 'failed'])}")
```

## 🤝 Contribuir

Para añadir una nueva acción:

1. Crear clase que hereda de `AbstractAction`
2. Implementar `name`, `is_needed()`, `execute()`, `verify()`
3. Registrar en `setup_actions()`
4. Añadir tests
5. Documentar

Ver [MIGRATION-GUIDE.md](docs/MIGRATION-GUIDE.md) para ejemplos completos.

## 📝 Notas de Versión

### v0.2.0 (Actual)

- ✨ Nueva arquitectura idempotente
- ✨ Action registry pattern
- ✨ Shared context entre acciones
- ✨ Mejor logging y reporting
- ✅ TimezoneAction migrado como ejemplo
- 📚 Documentación completa

### v0.1.0

- Sistema monolítico original
- Sin idempotencia
- Código menos mantenible

## 🙏 Créditos

Esta arquitectura se inspira en:
- **NixOS**: Sistema de configuración declarativa e idempotente
- **Ansible**: Módulos con check mode
- **Terraform**: Plan before apply

---

**Siguiente paso**: Migrar las acciones restantes siguiendo [MIGRATION-GUIDE.md](docs/MIGRATION-GUIDE.md) 🚀
