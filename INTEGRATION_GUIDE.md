# mangodb Integration Guide

## Overview

The `mangodb` repository contains all SQL database code for the mango training system. It is a separate, modular package that can be imported by other components.

## Integration Points

### 1. Launch (launch_ec2.py in finetune_safe)

**Location**: `/home/ubuntu/finetune_safe/launch_ec2.py:813-839`

```python
try:
    import sys
    sys.path.insert(0, '/home/ubuntu/mangodb')
    from training_db import insert_run, attach_conversation

    run_id = f"{Path(config_name).stem}_{instance_id}"
    insert_run(
        run_id=run_id,
        wandb_run_id=None,  # Will be updated when training starts
        config_dict=config,
        chain_of_custody_id=chain_of_custody_id,
        run_name=run_id,
        config_file_path=str(config_path),
        host='ec2',
        instance_id=instance_id
    )
    print(f" ✓ Run recorded in database: {run_id}")

    if conversation_s3_key:
        attach_conversation(run_id, conversation_s3_key)
        print(f" ✓ Conversation linked to run")
except Exception as e:
    print(f"   Warning: Could not record run in database: {e}")
    pass
```

**What it does**: Creates run record with full config from YAML

### 2. Training Start (train.py in finetune_safe)

**Location**: `/home/ubuntu/finetune_safe/finetune_safe/train.py:1601-1620`

```python
try:
    sys.path.insert(0, '/home/ubuntu/mangodb')
    from training_db import update_run_status
    from datetime import datetime

    run_id = os.environ.get('RUN_ID')
    if run_id and wandb.run:
        update_run_status(
            run_id,
            'running',
            wandb_run_id=wandb.run.id,
            wandb_url=wandb.run.url,
            started_at=datetime.utcnow()
        )
        print(f"✓ Updated training database: run_id={run_id}, wandb_run_id={wandb.run.id}", flush=True)
except Exception as e:
    print(f"Warning: Could not update training database with W&B run ID: {e}", flush=True)
    pass
```

**What it does**: Updates run with W&B run ID and URL once training starts

### 3. Crash (crash_notifications.py in finetune_safe)

**Location**: `/home/ubuntu/finetune_safe/finetune_safe/crash_notifications.py:585-605`

```python
try:
    import sys
    sys.path.insert(0, '/home/ubuntu/mangodb')
    from training_db import attach_crash_data

    error_log_s3_key = f'crash-reports/{run_id}/error.log'
    crash_report_s3_key = f'crash-reports/{run_id}/report.md'
    crash_analysis_s3_key = f'crash-reports/{run_id}/analysis.md'

    attach_crash_data(
        run_id=run_id,
        error_log_s3_key=error_log_s3_key,
        crash_report_s3_key=crash_report_s3_key,
        crash_analysis_s3_key=crash_analysis_s3_key
    )
    logger.info(f"✓ Crash data recorded in database for run {run_id}")
except Exception as e:
    logger.warning(f"Could not update database with crash data: {e}")
```

**What it does**: Attaches error logs and Bedrock analysis S3 keys to run record

## Environment Setup

### Required Environment Variable

Set in `~/.bashrc`:

```bash
export TRAINING_DB_PATH='/home/ubuntu/mango/data/training_runs.db'
```

### Python Path

The integration code adds mangodb to Python path:

```python
sys.path.insert(0, '/home/ubuntu/mangodb')
```

This allows importing:
```python
from training_db import init_db, insert_run, update_run_status, ...
```

## Database Initialization

Before first use, initialize the database:

```bash
python3 -c "import sys; sys.path.insert(0, '/home/ubuntu/mangodb'); from training_db import init_db; init_db()"
```

Or run migration if upgrading from v1:

```bash
cd /home/ubuntu/mangodb
python3 training_db/migrate_to_v2.py
```

## Testing Integration

### Test Database Functions

```bash
cd /home/ubuntu/mangodb
python3 training_db/test_db.py
python3 training_db/test_objectives.py
```

### Test From Integration Points

```python
# Test launch integration
import sys
sys.path.insert(0, '/home/ubuntu/mangodb')
from training_db import insert_run

insert_run(
    run_id='test_001',
    wandb_run_id=None,
    config_dict={'training': {'batch_size': 64}},
    host='ec2',
    instance_id='i-test'
)
print("✓ Launch integration working")

# Test training start integration
from training_db import update_run_status
update_run_status('test_001', 'running', wandb_run_id='abc123', wandb_url='https://wandb.ai/...')
print("✓ Training start integration working")

# Test crash integration
from training_db import attach_crash_data
attach_crash_data('test_001', 'error.log', 'report.md', 'analysis.md')
print("✓ Crash integration working")
```

## Error Handling

All database operations are wrapped in try/except blocks to ensure training never crashes due to database issues:

- **Launch**: If database insert fails, warning is printed but EC2 instance still launches
- **Training start**: If update fails, warning is printed but training continues
- **Crash**: If attach fails, warning is logged but crash notification still completes

## Migration from apis.training_db to mangodb

### Old Code (mango/apis/training_db)
```python
sys.path.insert(0, '/home/ubuntu/mango')
from apis.training_db import insert_run
```

### New Code (mangodb/training_db)
```python
sys.path.insert(0, '/home/ubuntu/mangodb')
from training_db import insert_run
```

### Files Updated

**finetune_safe repo (commit a135c627):**
- `launch_ec2.py`
- `finetune_safe/train.py`
- `finetune_safe/crash_notifications.py`

**mango repo:**
- Database code remains on branch `001-mcp-code-execution` (not merged to main)
- Will be removed once mangodb is fully tested

## Troubleshooting

### Import Error: "No module named 'training_db'"

**Cause**: Python path not set correctly

**Fix**:
```python
import sys
sys.path.insert(0, '/home/ubuntu/mangodb')
```

### Database File Not Found

**Cause**: TRAINING_DB_PATH environment variable not set

**Fix**:
```bash
export TRAINING_DB_PATH='/home/ubuntu/mango/data/training_runs.db'
source ~/.bashrc
```

### Database Locked Error

**Cause**: Multiple processes accessing SQLite simultaneously

**Fix**: SQLite has limited concurrency. For high-concurrency use cases, migrate to PostgreSQL.

## Future: PostgreSQL Migration

When ready to migrate from SQLite to PostgreSQL:

1. The database API is database-agnostic - no code changes needed
2. Update environment variables to point to PostgreSQL
3. Run migration script (will be provided)
4. All integration points continue working unchanged

## Summary

- **mangodb**: Standalone SQL database package
- **Integration**: 3 points (launch, train start, crash)
- **Import**: `from training_db import ...`
- **Error handling**: Always wrapped in try/except
- **Testing**: Comprehensive test suites provided
- **Modular**: Completely separate from main mango package
