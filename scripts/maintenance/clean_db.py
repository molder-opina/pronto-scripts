import os

from sqlalchemy import create_engine, text

# Default to standard development credentials if env vars not set (matching docker-compose/qa_automation)
DB_USER = os.environ.get("POSTGRES_USER", "pronto")
DB_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "pronto123")
DB_HOST = os.environ.get("POSTGRES_HOST", "localhost")
DB_PORT = os.environ.get("POSTGRES_PORT", "5432")
DB_NAME = os.environ.get("POSTGRES_DB", "pronto")

DB_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"


def clean_database():
    print("🧹 Cleaning database...")
    print(f"   Connecting to {DB_URL}...")

    engine = create_engine(DB_URL)

    with engine.connect() as conn, conn.begin():  # Start transaction
        # Delete dependent tables first
        print("   - Deleting Notifications...")
        conn.execute(text("DELETE FROM pronto_notifications"))

        print("   - Deleting Order Status History...")
        conn.execute(text("DELETE FROM pronto_order_status_history"))

        print("   - Deleting Order Item Modifiers...")
        conn.execute(text("DELETE FROM pronto_order_item_modifiers"))

        print("   - Deleting Order Items...")
        conn.execute(text("DELETE FROM pronto_order_items"))

        print("   - Deleting Orders...")
        conn.execute(text("DELETE FROM pronto_orders"))

        print("   - Deleting Waiter Calls...")
        conn.execute(text("DELETE FROM pronto_waiter_calls"))

        print("   - Deleting Feedback...")
        conn.execute(text("DELETE FROM pronto_feedback"))

        print("   - Deleting Dining Sessions...")
        conn.execute(text("DELETE FROM pronto_dining_sessions"))

    print("✨ Database cleaned successfully!")


if __name__ == "__main__":
    clean_database()
