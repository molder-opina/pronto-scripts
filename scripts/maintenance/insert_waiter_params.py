#!/usr/bin/env python3
"""
Script para insertar parámetros de configuración de campanita y realtime.
Ejecutar: python3 insert_waiter_params.py
"""

import sys
from pathlib import Path

# Agregar el directorio build al path
sys.path.insert(0, str(Path(__file__).parent / "build"))

from pronto_shared.services.business_config_service import set_config_value  # noqa: E402


def main():
    try:
        # Cooldown de campanita
        set_config_value(
            key="waiter_call_cooldown_seconds",
            value="10",
            value_type="integer",
            category="general",
            display_name="Cooldown de campanita (segundos)",
            description="Tiempo en segundos que la campanita permanece roja después de confirmar. Durante este tiempo no se permiten nuevas notificaciones.",
        )
        print("✓ Parámetro waiter_call_cooldown_seconds insertado")

        # Intervalo de polling
        set_config_value(
            key="realtime_poll_interval_ms",
            value="1000",
            value_type="integer",
            category="advanced",
            display_name="Intervalo de polling realtime (ms)",
            description="Intervalo en milisegundos para consultar eventos en tiempo real. Valores más bajos = notificaciones más rápidas pero más carga en el servidor.",
        )
        print("✓ Parámetro realtime_poll_interval_ms insertado")

        print("\n✅ Todos los parámetros insertados correctamente")
        return 0

    except Exception as e:
        print(f"❌ Error al insertar parámetros: {e}")
        import traceback

        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
