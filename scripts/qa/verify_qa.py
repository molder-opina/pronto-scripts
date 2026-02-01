import os
import urllib.request

from sqlalchemy import create_engine, text


def check_url(url, name):
    try:
        with urllib.request.urlopen(url) as response:
            status = response.getcode()
            print(f"[{'OK' if status == 200 else 'FAIL'}] {name} ({url}): {status}")
            return status == 200
    except Exception as e:
        print(f"[FAIL] {name} ({url}): {e}")
        return False


def check_db():
    print("\nChecking Database State...")
    db_url = f"postgresql://{os.environ.get('POSTGRES_USER','pronto')}:{os.environ.get('POSTGRES_PASSWORD','pronto123')}@{os.environ.get('POSTGRES_HOST','localhost')}:{os.environ.get('POSTGRES_PORT','5432')}/{os.environ.get('POSTGRES_DB','pronto')}"
    try:
        engine = create_engine(db_url)
        with engine.connect() as conn:
            # Check permissions
            perms = conn.execute(text("SELECT count(*) FROM pronto_system_permissions")).scalar()
            roles = conn.execute(text("SELECT count(*) FROM pronto_system_roles")).scalar()
            bindings = conn.execute(
                text("SELECT count(*) FROM pronto_role_permission_bindings")
            ).scalar()
            print(f"Permissions: {perms}")
            print(f"Roles: {roles}")
            print(f"Bindings: {bindings}")

            # Check Order
            order = (
                conn.execute(
                    text(
                        "SELECT id, total_amount, workflow_status FROM pronto_orders WHERE customer_email = 'luartx@gmail.com' ORDER BY id DESC LIMIT 1"
                    )
                )
                .mappings()
                .one_or_none()
            )
            if order:
                print(
                    f"Latest Order: #{order['id']} - Amount: ${order['total_amount']} - Status: {order['workflow_status']}"
                )
            else:
                print("No order found for luartx@gmail.com (Client flow check)")

    except Exception as e:
        print(f"DB Check Failed: {e}")


if __name__ == "__main__":
    print("--- QA VERIFICATION REPORT ---")
    c1 = check_url("http://localhost:6080", "Client App")
    c2 = check_url("http://localhost:6081/login", "Employee App")
    c3 = check_url("http://localhost:6082/health", "API")

    check_db()
