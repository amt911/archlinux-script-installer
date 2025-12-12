# Guía de Arquitectura Idempotente - Dasik

## 🎯 Objetivo

Esta nueva arquitectura permite que Dasik funcione de manera **idempotente** (como NixOS): ejecutar el mismo JSON varias veces no modificará el sistema si ya está configurado correctamente.

## 🏗️ Arquitectura

### Componentes Principales

```
┌─────────────────────────────────────────────────────────┐
│                  actions_handler_v2.py                   │
│  - Punto de entrada                                     │
│  - setup_actions(): Registra todas las acciones         │
│  - execute_installation(): Ejecuta el proceso           │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│                  ActionRegistry                          │
│  - Registro de acciones disponibles                     │
│  - Cada acción tiene: config_key, is_optional,          │
│    required_fields, depends_on                          │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│                  ActionExecutor                          │
│  1. Valida configuración                                │
│  2. Llama a is_needed() (IDEMPOTENCIA)                  │
│  3. Si es necesario → execute()                         │
│  4. Verifica con verify()                               │
│  5. Genera resumen                                      │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│              AbstractAction (cada acción)               │
│  - name: Nombre legible                                 │
│  - is_needed(): ¿Necesita ejecutarse?                   │
│  - execute(): Hacer los cambios                         │
│  - verify(): Verificar que funcionó                     │
└─────────────────────────────────────────────────────────┘
```

### Flujo de Ejecución

```
1. Cargar JSON
    ↓
2. Para cada acción registrada:
    ↓
3. ¿Configuración válida?
    ├─ No → Skip/Error
    └─ Sí ↓
4. is_needed()?  ← AQUÍ ESTÁ LA MAGIA DE IDEMPOTENCIA
    ├─ No → "Already configured"
    └─ Sí ↓
5. execute()
    ↓
6. verify()
    ↓
7. Siguiente acción
```

## ✨ Cómo Añadir Nuevas Acciones

### Paso 1: Crear la clase de acción

```python
from typing import Dict, Any
from .abstract_action import AbstractAction
from pathlib import Path

class MiNuevaAction(AbstractAction):
    """Descripción de lo que hace esta acción."""
    
    def __init__(self, config: Dict[str, Any], context=None):
        super().__init__(config, context)
        # Extraer configuración específica
        self.mi_parametro = config["mi_parametro"]
    
    @property
    def name(self) -> str:
        """Nombre mostrado al usuario."""
        return "Mi Nueva Funcionalidad"
    
    def is_needed(self) -> bool:
        """
        CLAVE: Aquí verificas si ya está configurado.
        
        Returns:
            True si NECESITA ejecutarse (no está configurado)
            False si YA está configurado correctamente
        """
        # Ejemplo: verificar si un archivo existe
        config_file = Path("/etc/mi_config.conf")
        
        if not config_file.exists():
            return True  # Necesita crearse
        
        # Verificar contenido
        content = config_file.read_text()
        expected = f"parametro={self.mi_parametro}\n"
        
        return content != expected  # True si difiere
    
    def execute(self) -> None:
        """Hacer los cambios reales."""
        print(f"Configurando {self.mi_parametro}...")
        
        # Tu lógica aquí
        Path("/etc/mi_config.conf").write_text(
            f"parametro={self.mi_parametro}\n"
        )
    
    def verify(self) -> bool:
        """
        Opcional: verificar que se aplicó correctamente.
        
        Returns:
            True si la verificación pasa
        """
        config_file = Path("/etc/mi_config.conf")
        return config_file.exists()
```

### Paso 2: Registrar la acción

Edita [actions_handler_v2.py](actions_handler_v2.py):

```python
def setup_actions() -> None:
    # ... imports existentes ...
    from .mi_nueva_action import MiNuevaAction
    
    # ... registros existentes ...
    
    # Añadir tu acción
    register_action(
        action_class=MiNuevaAction,
        config_key='mi_seccion',  # Clave en el JSON
        is_optional=True,  # ¿Es obligatoria?
        required_fields=['mi_parametro'],  # Campos requeridos
        depends_on=['hostname']  # Dependencias opcionales
    )
```

### Paso 3: Actualizar el JSON

```json
{
  "mi_seccion": {
    "mi_parametro": "valor"
  }
}
```

**¡Eso es todo!** No necesitas tocar el `ActionExecutor` ni nada más.

## 📋 Ejemplos de is_needed()

### Verificar archivo de configuración

```python
def is_needed(self) -> bool:
    config = Path("/etc/myconfig.conf")
    if not config.exists():
        return True
    
    content = config.read_text()
    return "my_setting=value" not in content
```

### Verificar symlink

```python
def is_needed(self) -> bool:
    link = Path("/etc/localtime")
    if not link.is_symlink():
        return True
    
    target = link.readlink()
    return str(target) != f"/usr/share/zoneinfo/{self.region}/{self.city}"
```

### Verificar paquete instalado

```python
def is_needed(self) -> bool:
    result = subprocess.run(
        ["pacman", "-Q", self.package_name],
        capture_output=True
    )
    return result.returncode != 0  # True = no está instalado
```

### Verificar servicio habilitado

```python
def is_needed(self) -> bool:
    result = subprocess.run(
        ["systemctl", "is-enabled", self.service_name],
        capture_output=True
    )
    return result.returncode != 0
```

## 🔄 Compartir Estado Entre Acciones

Si una acción necesita información de otra (ej: disk partitioning → base install):

```python
def execute(self) -> None:
    # Guardar en contexto
    self.context.set_partition("root", "/dev/sda1")
    self.context.set("custom_data", {"key": "value"})

# En otra acción:
def is_needed(self) -> bool:
    root_partition = self.context.get_partition("root")
    if root_partition:
        # Usar la partición
        pass
```

## 🧪 Testing de Idempotencia

```bash
# Primera ejecución: Debería configurar todo
sudo python -m dasik config.json

# Segunda ejecución: Debería decir "Already configured"
sudo python -m dasik config.json

# Resultado esperado:
# ℹ️  Already configured (idempotent):
#    • Timezone Configuration
#    • Locale Configuration
#    • Network Configuration
```

## 💡 Ventajas de esta Arquitectura

1. **Idempotente**: Ejecutar varias veces = seguro
2. **Escalable**: Añadir acción = 1 archivo + 1 registro
3. **Mantenible**: Cada acción es independiente
4. **Flexible**: Acciones opcionales se manejan automáticamente
5. **Testeable**: Fácil probar cada acción por separado
6. **Legible**: Código más claro y organizado

## 🔧 Migración desde el Viejo Sistema

Para mantener compatibilidad, el viejo `ActionsHandler` sigue existiendo pero internamente usa el nuevo sistema:

```python
# Viejo (sigue funcionando)
from dasik.lib.actions.actions_handler import ActionsHandler
handler = ActionsHandler("config.json")

# Nuevo (recomendado)
from dasik.lib.actions.actions_handler_v2 import setup_actions, execute_installation
setup_actions()
success = execute_installation("config.json")
```

## 📝 Checklist para Nueva Acción

- [ ] Crear clase que hereda de `AbstractAction`
- [ ] Implementar `name` property
- [ ] Implementar `is_needed()` con verificación de estado actual
- [ ] Implementar `execute()` con la lógica de configuración
- [ ] (Opcional) Implementar `verify()` para verificación post-ejecución
- [ ] Registrar en `setup_actions()`
- [ ] Añadir sección correspondiente en JSON de ejemplo
- [ ] Probar ejecución múltiple para verificar idempotencia
