#!/usr/bin/env python3
"""
Ejemplo de uso de la nueva arquitectura idempotente.

Este script demuestra cómo:
1. Registrar acciones personalizadas
2. Ejecutar instalación con idempotencia
3. Verificar que múltiples ejecuciones son seguras
"""

import sys
from pathlib import Path

# Añadir path al módulo dasik
sys.path.insert(0, str(Path(__file__).parent.parent))

from dasik.lib.actions import (
    setup_actions,
    execute_installation,
    AbstractAction,
    register_action
)
from typing import Dict, Any


class ExampleCustomAction(AbstractAction):
    """Acción de ejemplo que muestra cómo implementar idempotencia."""
    
    def __init__(self, config: Dict[str, Any], context=None):
        super().__init__(config, context)
        self.setting_value = config.get("value", "default")
    
    @property
    def name(self) -> str:
        return "Example Custom Configuration"
    
    def is_needed(self) -> bool:
        """Verifica si la configuración ya existe."""
        config_file = Path("/tmp/dasik_example.conf")
        
        if not config_file.exists():
            print("  → Config file doesn't exist, needs to be created")
            return True
        
        content = config_file.read_text()
        expected = f"setting={self.setting_value}\n"
        
        if content != expected:
            print(f"  → Config differs (got: {content.strip()}, want: {expected.strip()})")
            return True
        
        print(f"  → Config is already correct")
        return False
    
    def execute(self) -> None:
        """Crea o actualiza la configuración."""
        config_file = Path("/tmp/dasik_example.conf")
        config_file.write_text(f"setting={self.setting_value}\n")
        print(f"  ✓ Written config: setting={self.setting_value}")
    
    def verify(self) -> bool:
        """Verifica que la configuración se aplicó correctamente."""
        config_file = Path("/tmp/dasik_example.conf")
        if not config_file.exists():
            return False
        
        content = config_file.read_text()
        return f"setting={self.setting_value}\n" == content


def main():
    """Función principal de demostración."""
    print("="*70)
    print("DEMO: Arquitectura Idempotente de Dasik")
    print("="*70)
    
    # 1. Registrar acciones por defecto
    print("\n1. Registrando acciones del sistema...")
    setup_actions()
    
    # 2. Registrar acción personalizada
    print("2. Registrando acción personalizada de ejemplo...")
    register_action(
        action_class=ExampleCustomAction,
        config_key='example_config',
        is_optional=True,
        required_fields=['value']
    )
    
    # 3. Crear configuración de ejemplo
    import json
    example_config = {
        "example_config": {
            "value": "test123"
        },
        "enable_microcode": False
    }
    
    config_file = Path("/tmp/dasik_example_config.json")
    config_file.write_text(json.dumps(example_config, indent=2))
    print(f"3. Creado archivo de configuración: {config_file}")
    
    # 4. Primera ejecución
    print("\n" + "="*70)
    print("PRIMERA EJECUCIÓN (debería crear la configuración)")
    print("="*70)
    
    try:
        success = execute_installation(str(config_file))
        print(f"\nResultado: {'✓ Éxito' if success else '✗ Fallo'}")
    except Exception as e:
        print(f"\nError durante ejecución: {e}")
        # Es normal que falle porque no estamos en un entorno de instalación real
    
    # 5. Verificar que el archivo se creó
    example_output = Path("/tmp/dasik_example.conf")
    if example_output.exists():
        print(f"\n✓ Archivo creado: {example_output}")
        print(f"  Contenido: {example_output.read_text().strip()}")
    
    # 6. Segunda ejecución (idempotencia)
    print("\n" + "="*70)
    print("SEGUNDA EJECUCIÓN (debería detectar que ya está configurado)")
    print("="*70)
    
    try:
        success = execute_installation(str(config_file))
        print(f"\nResultado: {'✓ Éxito' if success else '✗ Fallo'}")
    except Exception as e:
        print(f"\nError durante ejecución: {e}")
    
    # 7. Modificar configuración
    print("\n" + "="*70)
    print("TERCERA EJECUCIÓN (con valor modificado)")
    print("="*70)
    
    example_config["example_config"]["value"] = "modified456"
    config_file.write_text(json.dumps(example_config, indent=2))
    
    try:
        success = execute_installation(str(config_file))
        print(f"\nResultado: {'✓ Éxito' if success else '✗ Fallo'}")
    except Exception as e:
        print(f"\nError durante ejecución: {e}")
    
    if example_output.exists():
        print(f"\n✓ Archivo actualizado: {example_output}")
        print(f"  Contenido nuevo: {example_output.read_text().strip()}")
    
    # Limpieza
    print("\n" + "="*70)
    print("Limpiando archivos temporales...")
    config_file.unlink(missing_ok=True)
    example_output.unlink(missing_ok=True)
    print("✓ Limpieza completada")
    
    print("\n" + "="*70)
    print("DEMO COMPLETADA")
    print("="*70)
    print("\nConceptos demostrados:")
    print("  1. Registro de acciones personalizadas")
    print("  2. Idempotencia: múltiples ejecuciones son seguras")
    print("  3. Detección de cambios: solo ejecuta cuando es necesario")
    print("  4. Actualización: detecta diferencias y actualiza")


if __name__ == "__main__":
    main()
