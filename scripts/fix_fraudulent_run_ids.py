#!/usr/bin/env python
"""Fix fraudulent run_id entries that have instance IDs instead of W&B run names"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path.home() / "mangodb"))
from training_db.core import get_connection

print("=" * 80)
print("FIXING FRAUDULENT RUN IDs")
print("=" * 80)

with get_connection() as conn:
    # Find runs where run_id contains instance ID but we have the real run_name
    cursor = conn.execute("""
        SELECT run_id, run_name, wandb_run_id
        FROM training_runs
        WHERE run_id LIKE '%_i-%' AND run_name IS NOT NULL AND run_name != ''
        ORDER BY created_at DESC
    """)

    fraudulent_runs = cursor.fetchall()

    print(f"\nFound {len(fraudulent_runs)} runs with fraudulent run_id\n")

    if len(fraudulent_runs) == 0:
        print("No fraudulent run IDs to fix")
        sys.exit(0)

    # Show what will be fixed
    for row in fraudulent_runs:
        print(f"  OLD: {row['run_id']}")
        print(f"  NEW: {row['run_name']}")
        print()

    print("=" * 80)

    # Update each one
    fixed_count = 0
    for row in fraudulent_runs:
        old_run_id = row['run_id']
        new_run_id = row['run_name']

        try:
            cursor = conn.execute("""
                UPDATE training_runs
                SET run_id = ?
                WHERE run_id = ?
            """, (new_run_id, old_run_id))

            conn.commit()
            print(f"✅ Fixed: {old_run_id} -> {new_run_id}")
            fixed_count += 1
        except Exception as e:
            print(f"❌ Error fixing {old_run_id}: {e}")

    print("=" * 80)
    print(f"✅ Fixed {fixed_count} fraudulent run IDs")
    print("=" * 80)
