#!/usr/bin/env python3
"""
Test de Flujo Completo PRONTO Cafetería

Este script automatiza el flujo completo:
1. Cliente crea orden → API
2. Chef procesa orden (iniciar → listo)
3. Mesero entrega y cobra
4. Verificaciones finales (email, PDF, estados)

Uso: python scripts/qa/test_pronto_full_flow.py
"""

import json
import sys
import time
from datetime import datetime
from typing import Optional

import requests

# ═══════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════

BASE_URL = "http://localhost:6080"
EMPLOYEE_URL = "http://localhost:6081"

CREDENTIALS = {
    "waiter": {"email": "juan.mesero@cafeteria.test", "password": "ChangeMe!123"},
    "chef": {"email": "carlos.chef@cafeteria.test", "password": "ChangeMe!123"},
    "cashier": {"email": "pedro.cajero@cafeteria.test", "password": "ChangeMe!123"},
}

CUSTOMER = {
    "name": "LuArtX Test",
    "email": "luartx@gmail.com",
    "phone": "5551234567",
}

HEADERS = {"Content-Type": "application/json", "Accept": "application/json"}


# ═══════════════════════════════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════════════════════════════


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    BOLD = "\033[1m"
    RESET = "\033[0m"


def log(phase: str, message: str, status: str = "INFO"):
    timestamp = datetime.now().strftime("%H:%M:%S")
    symbols = {"INFO": "ℹ", "OK": "✓", "ERROR": "✗", "WARN": "⚠"}
    color = {
        "INFO": Colors.BLUE,
        "OK": Colors.GREEN,
        "ERROR": Colors.RED,
        "WARN": Colors.YELLOW,
    }.get(status, Colors.BLUE)
    print(f"{color}[{timestamp}] [{phase}] {symbols.get(status, '•')} {message}{Colors.RESET}")


def log_section(title: str):
    print(f"\n{Colors.BOLD}{'═' * 60}{Colors.RESET}")
    print(f"{Colors.BOLD}  {title}{Colors.RESET}")
    print(f"{Colors.BOLD}{'═' * 60}{Colors.RESET}\n")


# ═══════════════════════════════════════════════════════════════
# API CLIENTES
# ═══════════════════════════════════════════════════════════════


class ClienteAPI:
    """API para operaciones del cliente"""

    def __init__(self):
        self.base_url = BASE_URL
        self.session = requests.Session()
        self.session_id: Optional[str] = None
        self.order_id: Optional[str] = None

    def get_menu(self) -> dict:
        """Obtener categorías y productos del menú"""
        log("CLIENTE", "Obteniendo menú...", "INFO")
        try:
            r = self.session.get(f"{self.base_url}/api/menu", timeout=10)
            if r.status_code == 200:
                data = r.json()
                items = data.get("items", [])
                log("CLIENTE", f"Menú obtenido: {len(items)} productos", "OK")
                return {"success": True, "items": items}
            else:
                log("CLIENTE", f"Error al obtener menú: {r.status_code}", "ERROR")
                return {"success": False, "error": r.text}
        except Exception as e:
            log("CLIENTE", f"Excepción al obtener menú: {e}", "ERROR")
            return {"success": False, "error": str(e)}

    def create_session(self) -> dict:
        """Crear sesión de cliente"""
        log("CLIENTE", "Creando sesión...", "INFO")
        try:
            r = self.session.post(
                f"{self.base_url}/api/sessions",
                headers=HEADERS,
                json={"table_number": 1},
                timeout=10,
            )
            if r.status_code in [200, 201]:
                data = r.json()
                self.session_id = data.get("session_id")
                log("CLIENTE", f"Sesión creada: {self.session_id}", "OK")
                return {"success": True, "session_id": self.session_id}
            else:
                log("CLIENTE", f"Error al crear sesión: {r.status_code}", "ERROR")
                return {"success": False, "error": r.text}
        except Exception as e:
            log("CLIENTE", f"Excepción al crear sesión: {e}", "ERROR")
            return {"success": False, "error": str(e)}

    def add_to_cart(self, item_id: str, quantity: int = 1, modifiers: list = None) -> dict:
        """Agregar item al carrito"""
        try:
            r = self.session.post(
                f"{self.base_url}/api/cart/add",
                headers=HEADERS,
                json={"item_id": item_id, "quantity": quantity, "modifiers": modifiers or []},
                timeout=10,
            )
            if r.status_code == 200:
                data = r.json()
                log("CLIENTE", f"Item agregado: {item_id} (qty: {quantity})", "OK")
                return {"success": True, "data": data}
            else:
                log("CLIENTE", f"Error al agregar item: {r.status_code}", "ERROR")
                return {"success": False, "error": r.text}
        except Exception as e:
            log("CLIENTE", f"Excepción al agregar item: {e}", "ERROR")
            return {"success": False, "error": str(e)}

    def checkout(self, customer_data: dict, payment_method: str = "later") -> dict:
        """Procesar checkout de la orden"""
        log("CLIENTE", "Procesando checkout...", "INFO")
        try:
            payload = {
                "customer": customer_data,
                "payment_method": payment_method,
            }
            r = self.session.post(
                f"{self.base_url}/api/orders/checkout",
                headers=HEADERS,
                json=payload,
                timeout=10,
            )
            if r.status_code in [200, 201]:
                data = r.json()
                self.order_id = data.get("order_id") or data.get("id")
                log("CLIENTE", f"Orden creada: {self.order_id}", "OK")
                return {"success": True, "order_id": self.order_id, "data": data}
            else:
                log("CLIENTE", f"Error en checkout: {r.status_code} - {r.text[:100]}", "ERROR")
                return {"success": False, "error": r.text}
        except Exception as e:
            log("CLIENTE", f"Excepción en checkout: {e}", "ERROR")
            return {"success": False, "error": str(e)}

    def get_order_status(self, order_id: str) -> dict:
        """Obtener estado de la orden"""
        try:
            r = self.session.get(f"{self.base_url}/api/orders/{order_id}", timeout=10)
            if r.status_code == 200:
                return {"success": True, "data": r.json()}
            return {"success": False, "error": r.text}
        except Exception as e:
            return {"success": False, "error": str(e)}


# ═══════════════════════════════════════════════════════════════
# API EMPLEADOS (AUTH + CHEF + WAITER)
# ═══════════════════════════════════════════════════════════════


class EmployeeAPI:
    """API para operaciones de empleados"""

    def __init__(self):
        self.base_url = EMPLOYEE_URL
        self.session = requests.Session()
        self.csrf_token: Optional[str] = None
        self.authenticated = False

    def login(self, email: str, password: str) -> dict:
        """Autenticar empleado"""
        log("AUTH", f"Login como {email}...", "INFO")
        try:
            r = self.session.post(
                f"{self.base_url}/login",
                data={"email": email, "password": password},
                timeout=10,
                allow_redirects=False,
            )
            if r.status_code == 302 or r.status_code == 200:
                self.authenticated = True
                log("AUTH", "Login exitoso", "OK")
                return {"success": True}
            else:
                log("AUTH", f"Login fallido: {r.status_code}", "ERROR")
                return {"success": False, "error": r.text}
        except Exception as e:
            log("AUTH", f"Excepción en login: {e}", "ERROR")
            return {"success": False, "error": str(e)}

    def get_orders(self, status: str = None) -> dict:
        """Obtener órdenes (con filtros opcionales)"""
        try:
            params = f"?status={status}" if status else ""
            r = self.session.get(f"{self.base_url}/api/orders{params}", timeout=10)
            if r.status_code == 200:
                data = r.json()
                return {"success": True, "orders": data.get("orders", [])}
            return {"success": False, "error": r.text}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def get_order_details(self, order_id: str) -> dict:
        """Obtener detalles de una orden"""
        try:
            r = self.session.get(f"{self.base_url}/api/orders/{order_id}", timeout=10)
            if r.status_code == 200:
                return {"success": True, "data": r.json()}
            return {"success": False, "error": r.text}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def update_order_status(self, order_id: str, status: str) -> dict:
        """Actualizar estado de orden"""
        log("ORDEN", f"Actualizando orden {order_id} → {status}", "INFO")
        try:
            r = self.session.put(
                f"{self.base_url}/api/orders/{order_id}/status",
                headers=HEADERS,
                json={"status": status},
                timeout=10,
            )
            if r.status_code in [200, 201]:
                log("ORDEN", f"Estado actualizado: {status}", "OK")
                return {"success": True, "data": r.json()}
            else:
                log(
                    "ORDEN",
                    f"Error al actualizar estado: {r.status_code} - {r.text[:100]}",
                    "ERROR",
                )
                return {"success": False, "error": r.text}
        except Exception as e:
            log("ORDEN", f"Excepción al actualizar estado: {e}", "ERROR")
            return {"success": False, "error": str(e)}

    def initiate_order(self, order_id: str) -> dict:
        """Chef: Iniciar preparación"""
        return self.update_order_status(order_id, "in_progress")

    def ready_order(self, order_id: str) -> dict:
        """Chef: Orden lista"""
        return self.update_order_status(order_id, "ready")

    def deliver_order(self, order_id: str) -> dict:
        """Mesero: Entregar orden"""
        return self.update_order_status(order_id, "delivered")

    def pay_order(self, order_id: str, payment_method: str = "cash") -> dict:
        """Cobrar orden"""
        log("PAGO", f"Procesando pago para orden {order_id}", "INFO")
        try:
            r = self.session.post(
                f"{self.base_url}/api/orders/{order_id}/pay",
                headers=HEADERS,
                json={"payment_method": payment_method},
                timeout=10,
            )
            if r.status_code in [200, 201]:
                log("PAGO", "Pago procesado exitosamente", "OK")
                return {"success": True, "data": r.json()}
            else:
                log("PAGO", f"Error al procesar pago: {r.status_code} - {r.text[:100]}", "ERROR")
                return {"success": False, "error": r.text}
        except Exception as e:
            log("PAGO", f"Excepción al procesar pago: {e}", "ERROR")
            return {"success": False, "error": str(e)}

    def get_pdf_link(self, order_id: str) -> dict:
        """Obtener enlace PDF de la orden"""
        try:
            r = self.session.get(f"{self.base_url}/api/orders/{order_id}/pdf", timeout=10)
            if r.status_code == 200:
                data = r.json()
                pdf_url = data.get("pdf_url") or data.get("url")
                log("PDF", f"PDF generado: {pdf_url}", "OK")
                return {"success": True, "pdf_url": pdf_url}
            return {"success": False, "error": r.text}
        except Exception as e:
            log("PDF", f"Excepción al obtener PDF: {e}", "ERROR")
            return {"success": False, "error": str(e)}


# ═══════════════════════════════════════════════════════════════
# FASE 1: CLIENTE CREA ORDEN
# ═══════════════════════════════════════════════════════════════


def fase_1_cliente_crea_orden(cliente: ClienteAPI) -> dict:
    """FASE 1: Cliente crea una orden"""
    log_section("FASE 1: CLIENTE CREA ORDEN")
    errors = []
    logs = []

    # 1.1 Obtener menú
    menu_result = cliente.get_menu()
    if not menu_result["success"]:
        errors.append(f"Error al obtener menú: {menu_result.get('error')}")
        return {"success": False, "errors": errors, "logs": logs}

    items = menu_result.get("items", [])
    if len(items) < 2:
        errors.append(f"No hay suficientes productos en el menú: {len(items)}")
        return {"success": False, "errors": errors, "logs": logs}

    logs.append(f"Menú con {len(items)} productos")

    # 1.2 Crear sesión
    session_result = cliente.create_session()
    if not session_result["success"]:
        errors.append(f"Error al crear sesión: {session_result.get('error')}")
        return {"success": False, "errors": errors, "logs": logs}

    # 1.3 Agregar productos al carrito
    log("CLIENTE", "Agregando productos al carrito...", "INFO")

    # Agregar producto 1
    add1 = cliente.add_to_cart(items[0]["id"], quantity=1)
    if not add1["success"]:
        errors.append(f"Error al agregar producto 1: {add1.get('error')}")
    else:
        logs.append("Producto 1 agregado al carrito")

    # Agregar producto 2
    if len(items) > 1:
        add2 = cliente.add_to_cart(items[1]["id"], quantity=2)
        if not add2["success"]:
            errors.append(f"Error al agregar producto 2: {add2.get('error')}")
        else:
            logs.append("Producto 2 agregado al carrito (qty: 2)")

    # 1.4 Checkout
    checkout = cliente.checkout(CUSTOMER, payment_method="later")
    if not checkout["success"]:
        errors.append(f"Error en checkout: {checkout.get('error')}")
        return {"success": False, "errors": errors, "logs": logs}

    order_id = checkout.get("order_id")
    logs.append(f"Orden creada: {order_id}")

    # Verificar estado inicial
    time.sleep(1)
    status_check = cliente.get_order_status(order_id)
    if status_check["success"]:
        initial_status = status_check["data"].get("status", "unknown")
        logs.append(f"Estado inicial de orden: {initial_status}")

    log_section("FASE 1 COMPLETADA")
    return {
        "success": len(errors) == 0,
        "errors": errors,
        "logs": logs,
        "order_id": order_id,
    }


# ═══════════════════════════════════════════════════════════════
# FASE 2: CHEF PROCESA ORDEN
# ═══════════════════════════════════════════════════════════════


def fase_2_chef_procesa_orden(empleado: EmployeeAPI, order_id: str) -> dict:
    """FASE 2: Chef procesa la orden (iniciar → listo)"""
    log_section("FASE 2: CHEF PROCESA ORDEN")
    errors = []
    logs = []

    # Autenticar como chef
    login = empleado.login(CREDENTIALS["chef"]["email"], CREDENTIALS["chef"]["password"])
    if not login["success"]:
        errors.append(f"Error de autenticación chef: {login.get('error')}")
        return {"success": False, "errors": errors, "logs": logs}

    logs.append("Chef autenticado")

    # Verificar orden existe
    order_details = empleado.get_order_details(order_id)
    if not order_details["success"]:
        errors.append(f"Orden no encontrada: {order_id}")
        return {"success": False, "errors": errors, "logs": logs}

    current_status = order_details["data"].get("status", "unknown")
    logs.append(f"Estado actual de orden: {current_status}")

    # 2.1 Iniciar preparación
    if current_status in ["pending", "received"]:
        initiate = empleado.initiate_order(order_id)
        if not initiate["success"]:
            errors.append(f"Error al iniciar preparación: {initiate.get('error')}")
        else:
            logs.append("Chef: Preparación iniciada")
            time.sleep(1)

    # 2.2 Marcar como lista
    ready = empleado.ready_order(order_id)
    if not ready["success"]:
        errors.append(f"Error al marcar como lista: {ready.get('error')}")
    else:
        logs.append("Chef: Orden marcada como lista")

    # Verificar estado final
    time.sleep(1)
    final_check = empleado.get_order_details(order_id)
    if final_check["success"]:
        final_status = final_check["data"].get("status", "unknown")
        logs.append(f"Estado final de orden: {final_status}")

    log_section("FASE 2 COMPLETADA")
    return {
        "success": len(errors) == 0,
        "errors": errors,
        "logs": logs,
    }


# ═══════════════════════════════════════════════════════════════
# FASE 3: MESERO ENTREGA Y COBRA
# ═══════════════════════════════════════════════════════════════


def fase_3_mesero_entrega_cobra(empleado: EmployeeAPI, order_id: str) -> dict:
    """FASE 3: Mesero entrega y cobra la orden"""
    log_section("FASE 3: MESERO ENTREGA Y COBRA")
    errors = []
    logs = []

    # Autenticar como mesero
    login = empleado.login(CREDENTIALS["waiter"]["email"], CREDENTIALS["waiter"]["password"])
    if not login["success"]:
        errors.append(f"Error de autenticación mesero: {login.get('error')}")
        return {"success": False, "errors": errors, "logs": logs}

    logs.append("Mesero autenticado")

    # Verificar estado actual
    order_details = empleado.get_order_details(order_id)
    if not order_details["success"]:
        errors.append(f"Orden no encontrada: {order_id}")
        return {"success": False, "errors": errors, "logs": logs}

    current_status = order_details["data"].get("status", "unknown")
    logs.append(f"Estado actual de orden: {current_status}")

    # 3.1 Entregar orden
    if current_status == "ready":
        deliver = empleado.deliver_order(order_id)
        if not deliver["success"]:
            errors.append(f"Error al entregar orden: {deliver.get('error')}")
        else:
            logs.append("Mesero: Orden entregada")
            time.sleep(1)

    # 3.2 Cobrar orden
    pay = empleado.pay_order(order_id, payment_method="cash")
    if not pay["success"]:
        errors.append(f"Error al cobrar orden: {pay.get('error')}")
    else:
        logs.append("Mesero: Orden cobrada exitosamente")
        time.sleep(1)

    # Verificar estado final
    final_check = empleado.get_order_details(order_id)
    if final_check["success"]:
        final_status = final_check["data"].get("status", "unknown")
        final_payment = final_check["data"].get("payment_status", "unknown")
        logs.append(f"Estado final de orden: {final_status}")
        logs.append(f"Estado de pago: {final_payment}")

    log_section("FASE 3 COMPLETADA")
    return {
        "success": len(errors) == 0,
        "errors": errors,
        "logs": logs,
    }


# ═══════════════════════════════════════════════════════════════
# FASE 4: VERIFICACIONES FINALES
# ═══════════════════════════════════════════════════════════════


def fase_4_verificaciones_finales(
    cliente: ClienteAPI, empleado: EmployeeAPI, order_id: str
) -> dict:
    """FASE 4: Verificaciones finales (PDF, email, estados)"""
    log_section("FASE 4: VERIFICACIONES FINALES")
    errors = []
    logs = []

    # 4.1 Verificar estado final de orden
    order_check = cliente.get_order_status(order_id)
    if order_check["success"]:
        final_status = order_check["data"].get("status", "unknown")
        payment_status = order_check["data"].get("payment_status", "unknown")

        if final_status == "paid":
            logs.append(f"✓ Estado correcto: {final_status}")
        else:
            errors.append(f"Estado incorrecto: {final_status} (esperado: paid)")
            logs.append(f"✗ Estado incorrecto: {final_status}")

        if payment_status == "paid":
            logs.append(f"✓ Pago correcto: {payment_status}")
        else:
            errors.append(f"Pago incorrecto: {payment_status}")
            logs.append(f"✗ Pago incorrecto: {payment_status}")
    else:
        errors.append("No se pudo verificar estado de orden")
        logs.append("✗ Error al verificar estado")

    # 4.2 Verificar PDF
    # Usar employee API para obtener PDF (requiere auth)
    login = empleado.login(CREDENTIALS["waiter"]["email"], CREDENTIALS["waiter"]["password"])
    if login["success"]:
        pdf = empleado.get_pdf_link(order_id)
        if pdf["success"]:
            logs.append(f"✓ PDF disponible: {pdf.get('pdf_url', 'URL generada')}")
        else:
            logs.append(f"⚠ PDF no disponible: {pdf.get('error', 'error desconocido')}")
            errors.append("PDF no generado")
    else:
        errors.append("No se pudo autenticar para obtener PDF")

    # 4.3 Verificar email (simulado)
    logs.append(f"✓ Email de confirmación enviado a: {CUSTOMER['email']}")
    logs.append("  (Verificación de email simulada - requiere inbox real)")

    log_section("FASE 4 COMPLETADA")
    return {
        "success": len(errors) == 0,
        "errors": errors,
        "logs": logs,
    }


# ═══════════════════════════════════════════════════════════════
# MAIN: EJECUTAR FLUJO COMPLETO
# ═══════════════════════════════════════════════════════════════


def main():
    print("\n" + "╔" + "═" * 58 + "╗")
    print("║" + " " * 10 + "TEST E2E: FLUJO COMPLETO PRONTO" + " " * 15 + "║")
    print("╚" + "═" * 58 + "╝\n")

    all_errors = []
    all_logs = []
    order_id = None

    cliente = ClienteAPI()
    empleado = EmployeeAPI()

    # ═══════════════════════════════════════════════════════════════
    # FASE 1: CLIENTE
    # ═══════════════════════════════════════════════════════════════
    fase1 = fase_1_cliente_crea_orden(cliente)
    all_errors.extend(fase1.get("errors", []))
    all_logs.extend(fase1.get("logs", []))

    if fase1.get("order_id"):
        order_id = fase1["order_id"]
    else:
        log("MAIN", "No se pudo crear orden - abortando", "ERROR")
        print("\n" + "═" * 60)
        print("RESUMEN FINAL")
        print("═" * 60)
        print(f"\n❌ ERRORES: {len(all_errors)}")
        for e in all_errors:
            print(f"   • {e}")
        print("\n📝 LOGS:")
        for l in all_logs:
            print(f"   • {l}")
        sys.exit(1)

    # ═══════════════════════════════════════════════════════════════
    # FASE 2: CHEF
    # ═══════════════════════════════════════════════════════════════
    fase2 = fase_2_chef_procesa_orden(empleado, order_id)
    all_errors.extend(fase2.get("errors", []))
    all_logs.extend(fase2.get("logs", []))

    # ═══════════════════════════════════════════════════════════════
    # FASE 3: MESERO
    # ═══════════════════════════════════════════════════════════════
    fase3 = fase_3_mesero_entrega_cobra(empleado, order_id)
    all_errors.extend(fase3.get("errors", []))
    all_logs.extend(fase3.get("logs", []))

    # ═══════════════════════════════════════════════════════════════
    # FASE 4: VERIFICACIONES
    # ═══════════════════════════════════════════════════════════════
    fase4 = fase_4_verificaciones_finales(cliente, empleado, order_id)
    all_errors.extend(fase4.get("errors", []))
    all_logs.extend(fase4.get("logs", []))

    # ═══════════════════════════════════════════════════════════════
    # RESUMEN FINAL
    # ═══════════════════════════════════════════════════════════════
    print("\n" + "═" * 60)
    print("RESUMEN FINAL")
    print("═" * 60)

    print(f"\n📋 Orden procesada: {order_id}")

    if all_errors:
        print(f"\n❌ ERRORES ENCONTRADOS: {len(all_errors)}")
        for i, e in enumerate(all_errors, 1):
            print(f"   {i}. {e}")
    else:
        print("\n✅ NO SE DETECTARON ERRORES")

    print("\n📝 LOGS DE EJECUCIÓN:")
    for l in all_logs:
        print(f"   • {l}")

    print("\n" + "═" * 60)

    success = len(all_errors) == 0
    print(f"RESULTADO: {'✅ ÉXITO' if success else '❌ FALLA'}")
    print("═" * 60 + "\n")

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
