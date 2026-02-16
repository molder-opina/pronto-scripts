
import os
from sqlalchemy import create_engine
from pronto_shared.models import Base

# Force import of all models to ensure they are registered in Base.metadata
# (models.py imports them but let's be sure code structure loads them)
# Actually models.py defines them all inline? Yes, I saw them.

def create_tables():
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        print("DATABASE_URL is not set.")
        return

    print(f"Connecting to {db_url}...")
    try:
        engine = create_engine(db_url)
        print("Creating all tables from Base.metadata...")
        Base.metadata.create_all(engine)
        print("Successfully created tables.")
    except Exception as e:
        print(f"Error creating tables: {e}")

if __name__ == "__main__":
    create_tables()
