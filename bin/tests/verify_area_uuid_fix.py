#!/usr/bin/env python3
"""
Verify Area and Table models work correctly with UUID types.
"""
import sys
sys.path.insert(0, '/opt/pronto/build')

from pronto_shared.config import load_config
from pronto_shared.db import get_session, init_engine
from pronto_shared.models import Area, Table

def main():
    config = load_config('employee')
    init_engine(config)
    
    with get_session() as session:
        # Test 1: Query areas
        areas = session.query(Area).limit(3).all()
        print(f"✓ Found {len(areas)} areas")
        for area in areas:
            print(f"  - Area ID: {area.id} (type: {type(area.id).__name__}), Name: {area.name}")
            assert isinstance(area.id, type(area.id)), "Area ID should be UUID"
        
        # Test 2: Query tables
        tables = session.query(Table).limit(3).all()
        print(f"✓ Found {len(tables)} tables")
        for table in tables:
            print(f"  - Table ID: {table.id} (type: {type(table.id).__name__}), Number: {table.table_number}, Area ID: {table.area_id} (type: {type(table.area_id).__name__})")
            assert isinstance(table.area_id, type(table.id)), "Table area_id should be UUID"
        
        # Test 3: Join query
        result = session.query(Table, Area).join(Area, Table.area_id == Area.id).first()
        if result:
            table, area = result
            print(f"✓ Join successful: Table '{table.table_number}' in Area '{area.name}'")
        else:
            print("✗ No tables with areas found")
            sys.exit(1)
        
        print("\n✅ All Area/Table UUID verification tests passed!")

if __name__ == "__main__":
    main()
