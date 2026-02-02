from sqlalchemy import select

from pronto_shared.config import load_config
from pronto_shared.db import get_session, init_engine
from pronto_shared.models import Table

# Init DB
config = load_config("pronto-employees")
init_engine(config)

restaurant_slug = "pronto"


def _generate_qr_code(table_number: str, text: str) -> str:
    import hashlib
    import time

    unique_string = f"{text}-{table_number}-{int(time.time())}"
    return hashlib.sha256(unique_string.encode()).hexdigest()[:16]


with get_session() as session:
    print("Checking for generic tables (M-MXX)...")

    tables_created = 0
    for i in range(1, 11):  # Generar hasta la 10 por si acaso
        # Force "M" code manually
        code = f"M-M{i:02d}"

        existing = session.execute(
            select(Table).where(Table.table_number == code)
        ).scalar_one_or_none()

        if existing:
            print(f"Table {code} already exists.")
            continue

        print(f"Creating table {code}...")
        new_table = Table(
            table_number=code,
            qr_code=_generate_qr_code(code, restaurant_slug),
            zone="General",
            capacity=4,
            position_x=(i - 1) * 100,
            position_y=0,  # Diferente posición para identificarlas
            shape="square",
        )
        session.add(new_table)
        tables_created += 1

    if tables_created > 0:
        session.commit()
        print(f"Successfully created {tables_created} generic tables.")
    else:
        print("No new tables needed.")
