"""
Migration Script: v1 → v2

Upgrades the training database schema from v1 to v2:
1. Creates run_objectives table
2. Adds new columns to training_runs table
3. Backfills objectives from existing runs
"""

import sqlite3
import os
import json
from datetime import datetime


def migrate_to_v2():
    """Run migration from v1 to v2"""
    db_path = os.environ.get('TRAINING_DB_PATH', '/home/ubuntu/mango/data/training_runs.db')

    if not os.path.exists(db_path):
        print(f"Database not found at {db_path}")
        print("Run init_db() first to create database")
        return False

    print("="*80)
    print("MIGRATING TRAINING DATABASE: v1 → v2")
    print("="*80)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Step 1: Check if migration needed
    print("\n1. Checking current schema...")
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]

    if 'run_objectives' in tables:
        print("   ✓ run_objectives table already exists")
        print("   Migration may have already been run. Checking columns...")
    else:
        print("   ⚠ run_objectives table missing - migration needed")

    # Step 2: Add new columns to training_runs
    print("\n2. Adding new columns to training_runs...")
    new_columns = [
        ('gradient_accumulation_steps', 'INTEGER'),
        ('max_steps', 'INTEGER'),
        ('max_grad_norm', 'REAL'),
        ('mixed_precision', 'BOOLEAN'),
        ('gradient_checkpointing', 'BOOLEAN'),
        ('fp16', 'BOOLEAN'),
        ('bf16', 'BOOLEAN'),
        ('enable_moving_targets', 'BOOLEAN'),
        ('return_groups', 'BOOLEAN'),
        ('n_clusters', 'INTEGER'),
        ('final_loss', 'REAL'),
        ('final_grad_norm', 'REAL'),
        ('final_learning_rate', 'REAL'),
        ('total_training_steps', 'INTEGER'),
    ]

    for col_name, col_type in new_columns:
        try:
            cursor.execute(f"ALTER TABLE training_runs ADD COLUMN {col_name} {col_type}")
            print(f"   ✓ Added column: {col_name}")
        except sqlite3.OperationalError as e:
            if 'duplicate column' in str(e).lower():
                print(f"   - Column already exists: {col_name}")
            else:
                print(f"   ✗ Error adding {col_name}: {e}")

    conn.commit()

    # Step 3: Create run_objectives table
    print("\n3. Creating run_objectives table...")
    try:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS run_objectives (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id TEXT NOT NULL,
                objective_name TEXT NOT NULL,
                objective_alias TEXT,
                uniprot TEXT,
                weight REAL,
                direction TEXT,
                raw_mean REAL,
                normalized_mean REAL,
                raw_std REAL,
                normalized_std REAL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (run_id) REFERENCES training_runs(run_id) ON DELETE CASCADE
            )
        """)
        print("   ✓ Created run_objectives table")

        # Create indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_obj_run_id ON run_objectives(run_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_obj_name ON run_objectives(objective_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_obj_raw_mean ON run_objectives(raw_mean)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_obj_normalized_mean ON run_objectives(normalized_mean)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_obj_direction ON run_objectives(direction)")
        cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_obj_run_name ON run_objectives(run_id, objective_name)")
        print("   ✓ Created indexes on run_objectives")

        conn.commit()
    except sqlite3.OperationalError as e:
        print(f"   - Table/indexes may already exist: {e}")

    # Step 4: Backfill objectives from existing runs
    print("\n4. Backfilling objectives from existing runs...")
    cursor.execute("SELECT run_id, config_json, final_metrics_json FROM training_runs")
    runs = cursor.fetchall()

    backfilled = 0
    skipped = 0

    for run_id, config_json, final_metrics_json in runs:
        if not config_json:
            skipped += 1
            continue

        try:
            config = json.loads(config_json)
            objectives = config.get('objectives', [])

            if not objectives:
                skipped += 1
                continue

            # Insert each objective
            for obj in objectives:
                obj_name = obj.get('name')
                obj_alias = obj.get('alias')
                uniprot = obj.get('params', {}).get('uniprot')
                weight = obj.get('weight')
                direction = obj.get('direction')

                try:
                    cursor.execute("""
                        INSERT OR IGNORE INTO run_objectives (
                            run_id, objective_name, objective_alias, uniprot,
                            weight, direction, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, (run_id, obj_name, obj_alias, uniprot, weight, direction, datetime.utcnow()))
                    backfilled += 1
                except Exception as e:
                    pass

            # Backfill final metrics if available
            if final_metrics_json:
                try:
                    metrics = json.loads(final_metrics_json)
                    for key, value in metrics.items():
                        if key.startswith('objectives/'):
                            # Parse: objectives/COMT_activity_maximize/raw_mean
                            parts = key.split('/')
                            if len(parts) == 3:
                                obj_alias = parts[1]
                                metric_type = parts[2]

                                # Extract objective name (remove _maximize/_minimize)
                                obj_name = obj_alias.replace('_maximize', '').replace('_minimize', '')

                                # Update metric
                                column_map = {
                                    'raw_mean': 'raw_mean',
                                    'normalized_mean': 'normalized_mean',
                                    'raw_std': 'raw_std',
                                    'normalized_std': 'normalized_std'
                                }

                                if metric_type in column_map:
                                    cursor.execute(f"""
                                        UPDATE run_objectives
                                        SET {column_map[metric_type]} = ?
                                        WHERE run_id = ? AND objective_name = ?
                                    """, (value, run_id, obj_name))
                except Exception as e:
                    pass

        except json.JSONDecodeError:
            skipped += 1
            continue

    conn.commit()
    print(f"   ✓ Backfilled {backfilled} objectives")
    print(f"   - Skipped {skipped} runs (no config or objectives)")

    # Step 5: Verify migration
    print("\n5. Verifying migration...")
    cursor.execute("SELECT COUNT(*) FROM run_objectives")
    obj_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM training_runs")
    run_count = cursor.fetchone()[0]

    print(f"   ✓ Database has {run_count} runs")
    print(f"   ✓ Database has {obj_count} objectives")

    if obj_count > 0:
        cursor.execute("""
            SELECT objective_name, COUNT(*) as count
            FROM run_objectives
            GROUP BY objective_name
            ORDER BY count DESC
            LIMIT 10
        """)
        print(f"\n   Top objectives:")
        for obj_name, count in cursor.fetchall():
            print(f"     - {obj_name}: {count} runs")

    conn.close()

    print("\n" + "="*80)
    print("MIGRATION COMPLETE ✓")
    print("="*80)
    print("\nYou can now use:")
    print("  - insert_objective()")
    print("  - update_objective_metric()")
    print("  - query_runs_by_objectives()")
    print("  - get_objective_statistics()")
    print("  - compare_gradient_methods()")

    return True


if __name__ == '__main__':
    migrate_to_v2()
