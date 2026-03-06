import sys
import os
import json
from http import HTTPStatus
from unittest.mock import patch, MagicMock

# Add paths for pronto_shared and api_app
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-libs/src"))
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-api/src"))

from pronto_shared.config import load_config
from pronto_shared.db import init_engine, get_session
from pronto_shared.models import SystemSetting
from pronto_shared.config_contract import CONFIG_CONTRACT

from flask import Flask

def run_verification():
    print("🚀 Iniciando Verificación de Blindaje V6 (Strict RBAC & Namespace)")
    
    config = load_config("employees")
    init_engine(config)
    
    # Setup Flask app for testing routes
    from api_app.routes.employees.config import bp as config_bp
    app = Flask(__name__)
    app.register_blueprint(config_bp)
    
    with app.test_request_context():
        # --- TEST 1: Admin no debe ver llaves system.* ---
        print("\n🔍 Test 1: Filtrado de Namespace (Admin)")
        user_mock = {'employee_id': 1, 'employee_role': 'admin', 'active_scope': 'admin'}
        with patch('pronto_shared.jwt_middleware.get_current_user', return_value=user_mock):
            with patch('pronto_shared.jwt_middleware.get_employee_role', return_value='admin'):
                from api_app.routes.employees.config import get_config
                response, status = get_config()
                
                if status != 200:
                    print(f"  ❌ FAILURE: get_config returned {status}: {response}")
                    return
                
                configs = response.get("data", {}).get("configs", [])
                system_keys = [c["config_key"] for c in configs if c["config_key"].startswith("system.")]
                
                if system_keys:
                    print(f"  ❌ FAILURE: Admin puede ver llaves de sistema: {system_keys}")
                    return
                print("  ✅ SUCCESS: Admin no tiene acceso a namespace 'system.*'")

        # --- TEST 2: System solo debe ver system.* y allowlist ---
        print("\n🔍 Test 2: Filtrado de Namespace (System)")
        user_mock = {'employee_id': 1, 'employee_role': 'system', 'active_scope': 'system'}
        with patch('pronto_shared.jwt_middleware.get_current_user', return_value=user_mock):
            with patch('pronto_shared.jwt_middleware.get_employee_role', return_value='system'):
                from api_app.routes.employees.config import get_config
                response, status = get_config()
                
                configs = response.get("data", {}).get("configs", [])
                business_keys = [c["config_key"] for c in configs if not c["config_key"].startswith("system.") and c["config_key"] not in ["restaurant_name", "currency_code", "currency_symbol"]]
                
                if business_keys:
                    print(f"  ❌ FAILURE: System puede ver llaves de negocio prohibidas: {business_keys}")
                    return
                print("  ✅ SUCCESS: System solo ve su namespace y allowlist permitido")

        # --- TEST 3: Hard-Fail en Mutación de Identidad ---
        print("\n🔍 Test 3: Bloqueo de Mutación de Identidad")
        user_mock = {'employee_id': 1, 'employee_role': 'system', 'active_scope': 'system'}
        with patch('pronto_shared.jwt_middleware.get_current_user', return_value=user_mock):
            with patch('pronto_shared.jwt_middleware.get_employee_role', return_value='system'):
                with patch('flask.request.get_json', return_value={"config_key": "hacker_key", "value": "123"}):
                    from api_app.routes.employees.config import update_config
                    # Assume ID 1 exists for this test context or mock session
                    with patch('pronto_shared.db.get_session') as mock_session:
                        mock_setting = MagicMock(config_key="system.performance.poll_interval_ms")
                        mock_session.return_value.__enter__.return_value.get.return_value = mock_setting
                        
                        response, status = update_config(1)
                        if status != HTTPStatus.BAD_REQUEST:
                            print(f"  ❌ FAILURE: Se permitió intento de mutación de config_key (Status: {status})")
                            return
                print("  ✅ SUCCESS: Bloqueo de mutación de config_key verificado")

        # --- TEST 4: Exclusividad de Escritura ---
        print("\n🔍 Test 4: Exclusividad de Escritura (RBAC)")
        # Case: System tries to edit business key
        user_mock = {'employee_id': 1, 'employee_role': 'system', 'active_scope': 'system'}
        with patch('pronto_shared.jwt_middleware.get_current_user', return_value=user_mock):
            with patch('pronto_shared.jwt_middleware.get_employee_role', return_value='system'):
                with patch('flask.request.get_json', return_value={"value": "New Name"}):
                    with patch('pronto_shared.db.get_session') as mock_session:
                        mock_setting = MagicMock(config_key="restaurant_name")
                        mock_session.return_value.__enter__.return_value.get.return_value = mock_setting
                        
                        from api_app.routes.employees.config import update_config
                        response, status = update_config(1)
                        if status != HTTPStatus.FORBIDDEN:
                            print(f"  ❌ FAILURE: System pudo editar restaurant_name (Status: {status})")
                            return
        print("  ✅ SUCCESS: Exclusividad de escritura verificada (System no toca Business)")

        # --- TEST 5: Cero Tolerancia a Mayúsculas ---
        print("\n🔍 Test 5: Cero Tolerancia a Mayúsculas")
        with get_session() as s:
            from sqlalchemy import text
            # Use raw query to check DB state
            result = s.execute(text("SELECT key FROM pronto_system_settings WHERE key ~ '[A-Z]'")).scalars().all()
            if result:
                print(f"  ❌ FAILURE: Se encontraron llaves con mayúsculas en la DB: {result}")
                return
        print("  ✅ SUCCESS: No existen llaves legacy (UPPERCASE) en la base de datos")

    print("\n🏆 TODAS LAS VERIFICACIONES V6 PASARON EXITOSAMENTE")

if __name__ == "__main__":
    run_verification()
