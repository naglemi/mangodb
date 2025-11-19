#!/usr/bin/env python
"""Delete fake run entries that have instance IDs instead of real W&B run names"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path.home() / "mangodb"))
from training_db.core import get_connection

print("Finding fake run entries...")
print("=" * 80)

with get_connection() as conn:
    # Find runs where run_name still has instance ID format (fake entries)
    # Real W&B run names have hostname like "ip-172-31-44-52" or "exp-10-60"
    # Fake ones have instance ID like "i-0abc123"
    cursor = conn.execute("""
        SELECT run_id, run_name, wandb_run_id, status, created_at
        FROM training_runs
        WHERE run_name LIKE '%_i-%'
        ORDER BY created_at DESC
    """)

    fake_runs = cursor.fetchall()

    print(f"Found {len(fake_runs)} fake run entries\n")

    if len(fake_runs) == 0:
        print("No fake runs to delete")
        sys.exit(0)

    # Show what will be deleted
    for row in fake_runs[:10]:
        print(f"  {row['run_id']} | {row['status']} | {row['created_at'][:10]}")

    if len(fake_runs) > 10:
        print(f"  ... and {len(fake_runs) - 10} more")

    print("\n" + "=" * 80)

    # Delete them
    cursor = conn.execute("""
        DELETE FROM training_runs
        WHERE run_name LIKE '%_i-%'
    """)

    deleted_count = cursor.rowcount
    conn.commit()

    print(f"✅ Deleted {deleted_count} fake run entries")
    print("=" * 80)
