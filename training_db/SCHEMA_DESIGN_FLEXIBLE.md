# Training Database: Flexible Schema for ~200 W&B Attributes

## Problem Statement

W&B runs have ~200 attributes that vary between runs:
- **Config parameters**: ~50-100 items (batch_size, learning_rate, num_objectives, gradient_method, etc.)
- **Summary metrics**: ~100-150 items (final loss values, objective scores, training stats)
- **System metadata**: host, tags, runtime, timestamps
- **Objectives**: Variable count (3-20+ objectives per run)
- **Scaffolds**: Variable count (10-1000+ scaffolds)

**Key challenges**:
1. Attributes vary from run to run (not every run has the same objectives)
2. New objectives/metrics added over time
3. Need fast queries on common attributes (gradient_method, batch_size, etc.)
4. Need flexible storage for everything else
5. Need to support objective-specific queries ("find runs where COMT_activity > 0.8")

## Current Schema (v1)

```sql
CREATE TABLE training_runs (
  -- Identity
  run_id TEXT PRIMARY KEY,
  wandb_run_id TEXT UNIQUE,

  -- Key hyperparameters (extracted for fast queries)
  batch_size INTEGER,
  learning_rate REAL,
  beta REAL,
  gradient_method TEXT,
  num_gpus INTEGER,
  num_objectives INTEGER,
  num_scaffolds INTEGER,

  -- Flexible storage (JSONB)
  config_json TEXT,           -- Full config dict
  final_metrics_json TEXT,    -- Full summary dict

  -- ... other fields
);
```

**Limitations**:
- Only 7 extracted fields - can't query on other config params without JSON parsing
- Objectives buried in JSON - can't do "find runs where DRD5_activity > 0.8"
- No objective-specific indexing
- No scaffold-level storage

## Proposed Schema (v2): Hybrid Approach

### 1. Core Table: `training_runs`

Keep current structure but add more extracted fields based on frequency analysis:

```sql
CREATE TABLE training_runs (
  -- Identity
  run_id TEXT PRIMARY KEY,
  wandb_run_id TEXT UNIQUE,
  run_name TEXT,

  -- Timestamps
  created_at TIMESTAMP,
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  duration_seconds INTEGER,

  -- Status
  status TEXT DEFAULT 'launched',  -- launched, running, completed, failed, crashed

  -- Host/Environment
  host TEXT,  -- 'expanse' or 'ec2'
  instance_id TEXT,
  config_file_path TEXT,

  -- Chain of custody
  chain_of_custody_id TEXT,

  -- Extracted hyperparameters (TOP 20 most queried)
  batch_size INTEGER,
  learning_rate REAL,
  beta REAL,
  gradient_method TEXT,  -- mgda, pcgrad, imtlg, aligned_mtl, etc.
  num_gpus INTEGER,
  num_objectives INTEGER,
  num_scaffolds INTEGER,
  max_steps INTEGER,
  gradient_accumulation_steps INTEGER,
  max_grad_norm REAL,
  mixed_precision BOOLEAN,
  gradient_checkpointing BOOLEAN,
  enable_moving_targets BOOLEAN,
  n_clusters INTEGER,
  return_groups BOOLEAN,

  -- NEW: Extracted common training metrics
  final_loss REAL,
  final_grad_norm REAL,
  final_learning_rate REAL,
  total_training_steps INTEGER,

  -- Flexible storage (JSONB - stores ALL 200 attributes)
  config_json TEXT,           -- Full config dict (50-100 attrs)
  final_metrics_json TEXT,    -- Full W&B summary dict (100-150 attrs)

  -- Attachments (S3 keys)
  conversation_s3_key TEXT,
  error_log_s3_key TEXT,
  crash_report_s3_key TEXT,
  crash_analysis_s3_key TEXT,
  blog_post_url TEXT,

  -- Audit
  created_at_db TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at_db TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common queries
CREATE INDEX idx_gradient_method ON training_runs(gradient_method);
CREATE INDEX idx_status ON training_runs(status);
CREATE INDEX idx_host ON training_runs(host);
CREATE INDEX idx_created_at ON training_runs(created_at DESC);
CREATE INDEX idx_batch_size ON training_runs(batch_size);
CREATE INDEX idx_learning_rate ON training_runs(learning_rate);
```

### 2. New Table: `run_objectives`

Store per-objective final values for fast querying:

```sql
CREATE TABLE run_objectives (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,

  -- Objective identification
  objective_name TEXT NOT NULL,  -- e.g., "DRD5_activity", "COMT_activity", "QED"
  objective_alias TEXT,          -- e.g., "DRD5_activity_maximize"
  uniprot TEXT,                  -- e.g., "P21918" (for protein targets)

  -- Objective configuration
  weight REAL,
  direction TEXT,  -- 'maximize' or 'minimize'

  -- Final values
  raw_mean REAL,              -- objectives/DRD5_activity_maximize/raw_mean
  normalized_mean REAL,       -- objectives/DRD5_activity_maximize/normalized_mean
  raw_std REAL,
  normalized_std REAL,

  -- Metadata
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (run_id) REFERENCES training_runs(run_id) ON DELETE CASCADE
);

-- Indexes for objective queries
CREATE INDEX idx_obj_run_id ON run_objectives(run_id);
CREATE INDEX idx_obj_name ON run_objectives(objective_name);
CREATE INDEX idx_obj_raw_mean ON run_objectives(raw_mean);
CREATE INDEX idx_obj_normalized_mean ON run_objectives(normalized_mean);
CREATE UNIQUE INDEX idx_obj_run_name ON run_objectives(run_id, objective_name);
```

**Example queries enabled**:
```sql
-- Find runs where COMT_activity > 0.8
SELECT r.* FROM training_runs r
JOIN run_objectives o ON r.run_id = o.run_id
WHERE o.objective_name = 'COMT_activity' AND o.raw_mean > 0.8;

-- Compare MGDA vs PCGrad on DRD5
SELECT
  r.gradient_method,
  AVG(o.raw_mean) as avg_drd5,
  COUNT(*) as num_runs
FROM training_runs r
JOIN run_objectives o ON r.run_id = o.run_id
WHERE o.objective_name = 'DRD5_activity' AND r.status = 'completed'
GROUP BY r.gradient_method;
```

### 3. New Table: `run_scaffolds` (Phase 2 - Future)

Store per-scaffold results when needed:

```sql
CREATE TABLE run_scaffolds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  scaffold_id TEXT NOT NULL,  -- scaffold identifier

  -- Scaffold scores per objective
  scores_json TEXT,  -- {"DRD5": 0.85, "COMT": 0.72, ...}

  -- Aggregate stats
  pareto_rank INTEGER,
  cluster_id INTEGER,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (run_id) REFERENCES training_runs(run_id) ON DELETE CASCADE
);
```

## Data Ingestion Strategy

### At Launch (launch_ec2.py)

```python
from apis.training_db import insert_run

# Parse config YAML
config = yaml.safe_load(open(config_path))

# Extract key hyperparameters
hyperparams = {
    'batch_size': config['training']['batch_size'],
    'learning_rate': config['training']['learning_rate'],
    'gradient_method': config.get('gradient_method', 'standard'),
    'num_objectives': len(config.get('objectives', [])),
    'beta': config.get('reward', {}).get('beta', None),
    # ... extract other common fields
}

# Insert run with full config + extracted fields
insert_run(
    run_id=run_id,
    wandb_run_id=None,  # Will be set later
    config_dict=config,  # Stored in config_json
    **hyperparams  # Stored in dedicated columns
)

# Insert objectives
for obj in config.get('objectives', []):
    insert_objective(
        run_id=run_id,
        objective_name=obj['name'],
        objective_alias=obj.get('alias'),
        uniprot=obj.get('params', {}).get('uniprot'),
        weight=obj['weight'],
        direction=obj['direction']
    )
```

### On Completion (train.py or monitor)

```python
from apis.training_db import update_run_status, update_objectives
import wandb

# Fetch W&B summary
summary = wandb.run.summary._json_dict

# Update run with final metrics
update_run_status(
    run_id=run_id,
    status='completed',
    final_metrics_json=summary,  # Store ALL metrics in JSON
    # Extract common metrics
    final_loss=summary.get('train/loss'),
    final_grad_norm=summary.get('train/grad_norm'),
    total_training_steps=summary.get('_step'),
    duration_seconds=summary.get('_runtime')
)

# Update objectives with final values
for obj_name, obj_data in summary.items():
    if obj_name.startswith('objectives/'):
        # Parse: objectives/DRD5_activity_maximize/raw_mean
        parts = obj_name.split('/')
        if len(parts) == 3:
            objective_name = parts[1].replace('_maximize', '').replace('_minimize', '')
            metric_type = parts[2]  # raw_mean, normalized_mean, etc.

            update_objective_metric(
                run_id=run_id,
                objective_name=objective_name,
                metric_type=metric_type,
                value=obj_data
            )
```

## Query Interface

### Simple Queries (Use Extracted Fields)

```python
# Find all MGDA runs with batch_size > 64
runs = query_runs(filters={
    'gradient_method': 'mgda',
    'min_batch_size': 64,
    'status': 'completed'
})

# Find all runs with high learning rate
runs = query_runs(filters={
    'min_learning_rate': 1e-3
})
```

### Complex Queries (Use JSON + SQL)

```python
# SQLite JSON extraction (when we need non-extracted fields)
import sqlite3

conn = sqlite3.connect(DB_PATH)
cursor = conn.execute("""
    SELECT run_id, json_extract(config_json, '$.training.gradient_accumulation_steps') as gas
    FROM training_runs
    WHERE status = 'completed'
      AND json_extract(config_json, '$.training.gradient_accumulation_steps') > 4
""")
```

### Objective-Based Queries

```python
# Find runs with COMT > 0.8 AND DRD5 > 0.7
runs = query_runs_by_objectives({
    'COMT_activity': {'min': 0.8},
    'DRD5_activity': {'min': 0.7},
    'status': 'completed'
})

# SQL implementation:
cursor.execute("""
    SELECT DISTINCT r.*
    FROM training_runs r
    JOIN run_objectives o1 ON r.run_id = o1.run_id
    JOIN run_objectives o2 ON r.run_id = o2.run_id
    WHERE r.status = 'completed'
      AND o1.objective_name = 'COMT_activity' AND o1.raw_mean > 0.8
      AND o2.objective_name = 'DRD5_activity' AND o2.raw_mean > 0.7
""")
```

## Migration Path

### Phase 1 (Current - DONE ✅)
- Basic `training_runs` table with 7 extracted fields
- JSON storage for full config/metrics
- Integration with launch_ec2.py and crash_notifications.py

### Phase 2 (Next - THIS DOCUMENT)
- Add `run_objectives` table
- Expand extracted fields to top 20
- Add objective ingestion at launch
- Add objective updates on completion

### Phase 3 (Future)
- Migrate SQLite → PostgreSQL on AWS RDS
- Add `run_scaffolds` table for per-scaffold results
- Add real-time updates during training
- Add web UI for querying

## Implementation: New API Functions

```python
# apis/training_db/objectives.py

def insert_objective(run_id: str, objective_name: str, **kwargs):
    """Insert objective configuration at launch"""
    conn = _get_connection()
    conn.execute("""
        INSERT INTO run_objectives (
            run_id, objective_name, objective_alias, uniprot,
            weight, direction
        ) VALUES (?, ?, ?, ?, ?, ?)
    """, (
        run_id,
        objective_name,
        kwargs.get('objective_alias'),
        kwargs.get('uniprot'),
        kwargs.get('weight'),
        kwargs.get('direction')
    ))
    conn.commit()

def update_objective_metric(run_id: str, objective_name: str,
                            metric_type: str, value: float):
    """Update objective final value from W&B summary"""
    conn = _get_connection()

    # Map metric_type to column
    column_map = {
        'raw_mean': 'raw_mean',
        'normalized_mean': 'normalized_mean',
        'raw_std': 'raw_std',
        'normalized_std': 'normalized_std'
    }

    if metric_type not in column_map:
        return

    column = column_map[metric_type]
    conn.execute(f"""
        UPDATE run_objectives
        SET {column} = ?
        WHERE run_id = ? AND objective_name = ?
    """, (value, run_id, objective_name))
    conn.commit()

def query_runs_by_objectives(objective_filters: dict, **kwargs):
    """
    Query runs by objective thresholds

    Example:
        query_runs_by_objectives({
            'COMT_activity': {'min': 0.8, 'max': 1.0},
            'DRD5_activity': {'min': 0.7}
        }, status='completed')
    """
    # Build SQL with JOIN per objective
    # Returns list of runs matching ALL criteria
    pass
```

## Storage Estimates

### Current (v1):
- Training runs: 1KB per run
- 1000 runs = 1MB
- 100K runs = 100MB (very manageable)

### With objectives table (v2):
- Training runs: 1.5KB per run (more extracted fields)
- Objectives: 200 bytes per objective × 10 objectives = 2KB per run
- Total per run: ~3.5KB
- 100K runs = 350MB (still very manageable for SQLite)

### With scaffolds table (v3 - future):
- Scaffolds: 500 bytes per scaffold × 100 scaffolds = 50KB per run
- Total per run: ~54KB
- 100K runs = 5.4GB (approaching PostgreSQL territory)

## Decision: When to Migrate to PostgreSQL

**Stay on SQLite if**:
- < 10K runs
- < 1GB database size
- Single-machine queries only
- No concurrent writes

**Migrate to PostgreSQL when**:
- > 10K runs
- > 1GB database size
- Need web UI with concurrent queries
- Need advanced indexing (GIN, BRIN)
- Need JSONB query optimization
- Need replication/backups

## Summary

**Current v1 schema is GOOD for**:
- Storing all 200 attributes in JSON (✅)
- Fast queries on 7 key hyperparameters (✅)
- Basic filtering and sorting (✅)

**v2 schema (this document) adds**:
- 13 more extracted fields (top 20 total) (🎯)
- Dedicated objectives table for per-objective queries (🎯)
- Proper objective indexing (🎯)
- Enables "find runs where objective X > Y" queries (🎯)

**Implementation priority**:
1. Add objectives table + insert/update functions
2. Integrate objective ingestion at launch
3. Add objective updates on completion
4. Add query_runs_by_objectives() function
5. Expand extracted fields to top 20
6. Test on real runs
7. Update README with new API

**Backward compatibility**:
- All existing code continues to work (✅)
- JSON fields still contain ALL data (✅)
- Can query old runs with new schema (✅)
