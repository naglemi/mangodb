# mangodb

**SQL database infrastructure for the mango training system**

This repository contains all SQL database code for tracking training runs, configurations, metrics, and results. It is separate from the main `mango` package to keep database logic modular and maintainable.

## Structure

```
mangodb/
├── training_db/          # Training runs database
│   ├── __init__.py       # API exports
│   ├── core.py           # Core database operations
│   ├── objectives.py     # Objectives tracking
│   ├── schema_v2.sql     # Database schema
│   ├── migrate_to_v2.py  # Migration scripts
│   ├── test_db.py        # Tests
│   └── README.md         # Detailed documentation
└── README.md             # This file
```

## Installation

```bash
# Add to Python path
export PYTHONPATH="/home/ubuntu/mangodb:$PYTHONPATH"

# Or install in development mode
cd /home/ubuntu/mangodb
pip install -e .
```

## Usage

### From Python

```python
# Import from mangodb
from mangodb.training_db import (
    init_db,
    insert_run,
    update_run_status,
    query_runs,
    attach_crash_data,
)

# Initialize database
init_db()

# Insert a training run
insert_run(
    run_id='mgda_test_001',
    wandb_run_id=None,
    config_dict=config,
    chain_of_custody_id='ABC123',
    host='ec2',
    instance_id='i-abc123'
)

# Query runs
runs = query_runs(filters={
    'gradient_method': 'mgda',
    'status': 'completed',
    'min_batch_size': 64
})
```

### From Command Line

```bash
# Initialize database
python3 -c "from mangodb.training_db import init_db; init_db()"

# Migrate to v2
python3 /home/ubuntu/mangodb/training_db/migrate_to_v2.py

# Run tests
python3 /home/ubuntu/mangodb/training_db/test_db.py
python3 /home/ubuntu/mangodb/training_db/test_objectives.py
```

## Environment Variables

Set in `~/.bashrc`:

```bash
export TRAINING_DB_PATH='/home/ubuntu/mango/data/training_runs.db'
```

## Database Schema

### v2 (Current)

**Hybrid storage for ~200 W&B attributes:**
- **20 extracted columns** for fast queries (batch_size, learning_rate, gradient_method, etc.)
- **2 JSON columns** for complete data (config_json, final_metrics_json)
- **Objectives table** for per-objective queries

See `training_db/SCHEMA_DESIGN_FLEXIBLE.md` for details.

## Integration Points

### 1. At Launch (`launch_ec2.py`)

```python
from mangodb.training_db import insert_run

insert_run(
    run_id=run_id,
    wandb_run_id=None,
    config_dict=config,
    chain_of_custody_id=chain_of_custody_id,
    host='ec2',
    instance_id=instance_id
)
```

### 2. When Training Starts (`train.py`)

```python
from mangodb.training_db import update_run_status

update_run_status(
    run_id,
    'running',
    wandb_run_id=wandb.run.id,
    wandb_url=wandb.run.url
)
```

### 3. On Crash (`crash_notifications.py`)

```python
from mangodb.training_db import attach_crash_data

attach_crash_data(
    run_id,
    error_log_s3_key='crash-reports/{run_id}/error.log',
    crash_report_s3_key='crash-reports/{run_id}/report.md',
    crash_analysis_s3_key='crash-reports/{run_id}/analysis.md'
)
```

## Documentation

- `training_db/README.md` - API reference and examples
- `training_db/SCHEMA_DESIGN_FLEXIBLE.md` - Schema design rationale
- `training_db/DEPLOYMENT_SUMMARY.md` - Deployment guide
- `training_db/SIMPLIFIED_STRATEGY.md` - Data flow documentation

## Testing

```bash
# Test core functionality
python3 /home/ubuntu/mangodb/training_db/test_db.py

# Test objectives API
python3 /home/ubuntu/mangodb/training_db/test_objectives.py
```

## Migration

To upgrade from v1 to v2:

```bash
python3 /home/ubuntu/mangodb/training_db/migrate_to_v2.py
```

## Database Backend

- **Current**: SQLite at `/home/ubuntu/mango/data/training_runs.db`
- **Future**: PostgreSQL on AWS RDS (when IAM permissions obtained)

The API is database-agnostic - migration requires no code changes.

## License

Internal use only - part of the mango training system.
