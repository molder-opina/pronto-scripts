#!/usr/bin/env python3
"""
Quick verification script to check SQL seeds loaded correctly.
"""

import os
import sys
from pathlib import Path

# Add build to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "build"))

from sqlalchemy import func, select

from pronto_shared.config import load_config
from pronto_shared.db import get_session, init_engine
from pronto_shared.models import (
    Area,
    MenuCategory,
    MenuItem,
    Table,
)

def verify_seeds():
    """Verify that SQL seeds loaded correctly."""
    print("=" * 60)
    print("SQL SEEDS VERIFICATION")
    print("=" * 60)
    
    config = load_config("verify-seeds")
    init_engine(config)
    
    with get_session() as session:
        # Check categories
        categories_count = session.execute(select(func.count(MenuCategory.id))).scalar()
        print(f"\n✓ Categories: {categories_count} (expected: 12)")
        
        if categories_count > 0:
            categories = session.execute(select(MenuCategory).order_by(MenuCategory.display_order)).scalars().all()
            for cat in categories:
                print(f"  - {cat.name}")
        
        # Check menu items
        items_count = session.execute(select(func.count(MenuItem.id))).scalar()
        print(f"\n✓ Menu Items: {items_count} (expected: 94)")
        
        # Check areas
        areas_count = session.execute(select(func.count(Area.id))).scalar()
        print(f"\n✓ Areas: {areas_count} (expected: 3)")
        
        if areas_count > 0:
            areas = session.execute(select(Area)).scalars().all()
            for area in areas:
                print(f"  - {area.name} (prefix: {area.prefix})")
        
        # Check tables
        tables_count = session.execute(select(func.count(Table.id))).scalar()
        print(f"\n✓ Tables: {tables_count} (expected: 8)")
        
        if tables_count > 0:
            tables = session.execute(select(Table).order_by(Table.table_number)).scalars().all()
            for table in tables:
                print(f"  - {table.table_number} (capacity: {table.capacity}, area: {table.area.name})")
        
        # Summary
        print("\n" + "=" * 60)
        if categories_count >= 12 and items_count >= 90 and areas_count >= 3 and tables_count >= 8:
            print("✅ ALL SEEDS LOADED SUCCESSFULLY!")
        else:
            print("⚠️  SOME SEEDS MAY BE MISSING")
        print("=" * 60)

if __name__ == "__main__":
    verify_seeds()
