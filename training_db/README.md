# Training Runs Database API

**Centralized SQL database for tracking all training runs across the system.**

## Overview

This API provides a single source of truth for all training run metadata, replacing ad-hoc W&B queries with fast, queryable SQL storage. Data is attached at different lifecycle points:

- **At launch**: Run record created with config, chain_of_custody_id
- **During training**: Status updated, W&B run ID attached
- **On crash**: Error logs and Bedrock analysis attached
- **After blog post**: Blog URL attached
- **Manual actions**: Any additional metadata can be added

## Database Location

- **Current**: SQLite at `/home/ubuntu/mango/data/training_runs.db`
- **Future**: PostgreSQL on AWS RDS (when we get IAM permissions)

The API is database-agnostic - migration from SQLite to PostgreSQL requires no code changes.

## Quick Start

### Initialize Database

```bash
python3 -c "from apis.training_db import init_db; init_db()"
```

### Basic Usage

```python
from apis.training_db import insert_run, update_run_status, query_runs

# At launch
insert_run(
    run_id='config_i-abc123',
    wandb_run_id=None,
    config_dict=config,
    chain_of_custody_id='XYZ789',
    run_name='mgda_4gpu_test',
    config_file_path='/path/to/config.yaml',
    host='ec2',
    instance_id='i-abc123'
)

# During training
update_run_status(
    'config_i-abc123',
    'running',
    wandb_run_id='wandb_run_id',
    wandb_url='https://wandb.ai/...'
)

# Query runs
mgda_runs = query_runs(filters={'gradient_method': 'mgda'}, limit=50)
```

## Schema

### `training_runs` Table

**Primary Identification:**
- `run_id` (PK): Internal run ID (e.g., "config_i-abc123")
- `wandb_run_id` (UNIQUE): W&B run ID
- `wandb_url`: W&B run URL
- `run_name`: Human-readable run name

**Tracking:**
- `chain_of_custody_id`: Links conversation → training → crash → analysis

**Metadata:**
- `config_file_path`: Path to YAML config
- `host`: 'expanse' or 'ec2'
- `instance_id`: EC2 instance ID or Expanse job ID

**Timestamps:**
- `created_at`: When run record created
- `started_at`: When training actually started
- `ended_at`: When training finished/crashed
- `duration_seconds`: Total runtime

**Status:**
- `status`: 'launched', 'running', 'completed', 'failed', 'crashed'

**Key Hyperparameters** (extracted for fast queries):
- `batch_size`, `learning_rate`, `beta`
- `gradient_method` (mgda, pcgrad, etc.)
- `num_gpus`, `num_objectives`, `num_scaffolds`

**Flexible Storage** (JSON):
- `config_json`: Full config dictionary from YAML
- `final_metrics_json`: Final metrics from W&B

**Attachments** (S3 keys):
- `blog_post_url`: Blog post URL (added via workflow)
- `conversation_s3_key`: Conversation export S3 key
- `crash_report_s3_key`: Crash report S3 key
- `error_log_s3_key`: Error log S3 key
- `crash_analysis_s3_key`: Bedrock crash analysis S3 key

**Audit:**
- `created_at_db`: When record inserted
- `updated_at_db`: When record last updated (auto)

## API Reference

### Core Operations

#### `init_db()`
Initialize database with schema (idempotent).

```python
from apis.training_db import init_db
init_db()
```

#### `insert_run(run_id, wandb_run_id, config_dict, chain_of_custody_id=None, **kwargs)`
Insert new training run (called at launch).

**Args:**
- `run_id` (str): Unique run identifier
- `wandb_run_id` (str|None): W&B run ID (may be None at launch)
- `config_dict` (dict): Full config from YAML
- `chain_of_custody_id` (str|None): 6-character tracking ID
- `**kwargs`: `run_name`, `config_file_path`, `host`, `instance_id`

**Example:**
```python
insert_run(
    run_id='mgda_i-abc123',
    wandb_run_id=None,
    config_dict=config,
    chain_of_custody_id='ABC123',
    run_name='mgda_test',
    config_file_path='/path/to/config.yaml',
    host='ec2',
    instance_id='i-abc123'
)
```

#### `update_run_status(run_id, status, **kwargs)`
Update run status and optional fields.

**Args:**
- `run_id` (str): Run identifier
- `status` (str): New status ('running', 'completed', 'failed', 'crashed')
- `**kwargs`: Optional fields to update
  - `duration_seconds` (int)
  - `final_metrics_json` (dict)
  - `ended_at` (datetime|str)
  - `started_at` (datetime|str)
  - `wandb_run_id` (str)
  - `wandb_url` (str)

**Example:**
```python
update_run_status(
    'mgda_i-abc123',
    'completed',
    duration_seconds=3600,
    ended_at=datetime.utcnow(),
    final_metrics_json=wandb.run.summary._json_dict
)
```

#### `get_run(run_id)`
Get single run by ID.

**Returns:** Dict with all fields, or None if not found

```python
run = get_run('mgda_i-abc123')
print(f"Status: {run['status']}, Batch size: {run['batch_size']}")
```

#### `query_runs(filters=None, order_by='created_at DESC', limit=100)`
Flexible query interface.

**Filter Options:**
- `status` (str): Filter by status
- `host` (str): Filter by host ('expanse' or 'ec2')
- `gradient_method` (str): Filter by gradient method
- `min_duration_hours` (float): Minimum duration in hours
- `created_after` (str): ISO timestamp string
- `has_blog_post` (bool): Has blog post attached
- `has_crash_analysis` (bool): Has crash analysis attached

**Example:**
```python
# Get all completed MGDA runs from last week
from datetime import datetime, timedelta

runs = query_runs(
    filters={
        'status': 'completed',
        'gradient_method': 'mgda',
        'created_after': (datetime.utcnow() - timedelta(days=7)).isoformat() + 'Z',
        'min_duration_hours': 1.0
    },
    order_by='duration_seconds DESC',
    limit=50
)

print(f"Found {len(runs)} MGDA runs")
for run in runs:
    print(f"  {run['run_name']}: {run['duration_seconds']/3600:.1f}h")
```

### Attachment Operations

#### `attach_blog_post(run_id, blog_url)`
Attach blog post URL (called from blog workflow).

```python
attach_blog_post('mgda_i-abc123', 'https://app.michaelnagle.bio/posts/mgda-analysis')
```

#### `attach_crash_data(run_id, error_log_s3_key, crash_report_s3_key, crash_analysis_s3_key)`
Attach crash-related S3 keys (called from `crash_notifications.py`).

```python
attach_crash_data(
    'mgda_i-abc123',
    error_log_s3_key='crash-reports/mgda_i-abc123/error.log',
    crash_report_s3_key='crash-reports/mgda_i-abc123/report.md',
    crash_analysis_s3_key='crash-reports/mgda_i-abc123/analysis.md'
)
```

#### `attach_conversation(run_id, conversation_s3_key)`
Attach conversation context (called at launch).

```python
attach_conversation('mgda_i-abc123', 'conversations/mgda_i-abc123/conversation.json')
```

#### `get_stats()`
Get database statistics.

**Returns:** Dict with run counts by status

```python
stats = get_stats()
print(f"Total runs: {stats['total_runs']}")
print(f"Running: {stats['running']}")
print(f"Crashed: {stats['crashed']}")
print(f"With blog posts: {stats['with_blog_posts']}")
```

## Integration Points

### 1. Launch Integration (`launch_ec2.py`)

**Automatically integrated** - no manual action needed.

When `launch_ec2.py` creates a new EC2 instance:
1. Run record inserted with config, chain_of_custody_id
2. Conversation S3 key attached (if captured)

### 2. Crash Integration (`crash_notifications.py`)

**Automatically integrated** - no manual action needed.

When `notify_and_analyze_crash()` is called:
1. Run status updated to 'crashed'
2. Error log, crash report, and analysis S3 keys attached

### 3. Blog Post Integration

**Manual integration needed** - add to blog workflow:

```python
# In submit_blog_post.py or equivalent
from apis.training_db import attach_blog_post

# After successful blog deployment
for run_id in blog_post_metadata['run_ids']:
    attach_blog_post(run_id, blog_url)
```

### 4. Training Status Updates

**Future integration** - add to training wrapper:

```python
# At training start (in train.py or wrapper)
from apis.training_db import update_run_status
import wandb

update_run_status(
    run_id=os.environ['RUN_ID'],
    status='running',
    wandb_run_id=wandb.run.id,
    wandb_url=wandb.run.url,
    started_at=datetime.utcnow()
)

# At training end
update_run_status(
    run_id=os.environ['RUN_ID'],
    status='completed',
    ended_at=datetime.utcnow(),
    duration_seconds=int(time.time() - start_time),
    final_metrics_json=wandb.run.summary._json_dict
)
```

## Example Queries

### Find Best Performing Runs
```python
# Get top 10 runs by specific objective
runs = query_runs(
    filters={'status': 'completed', 'min_duration_hours': 2},
    order_by='created_at DESC',
    limit=100
)

# Parse final metrics and sort
import json
runs_with_comt = []
for run in runs:
    if run['final_metrics_json']:
        metrics = json.loads(run['final_metrics_json'])
        comt = metrics.get('objectives/COMT_activity_maximize/raw_mean')
        if comt:
            runs_with_comt.append((run, comt))

runs_with_comt.sort(key=lambda x: x[1], reverse=True)
print("Top 10 COMT performers:")
for run, comt in runs_with_comt[:10]:
    print(f"  {run['run_name']}: COMT={comt:.4f}, gradient_method={run['gradient_method']}")
```

### Compare Gradient Methods
```python
for method in ['mgda', 'pcgrad', 'imtlg', 'aligned_mtl']:
    runs = query_runs(
        filters={
            'gradient_method': method,
            'status': 'completed',
            'min_duration_hours': 1
        },
        limit=100
    )

    success_rate = len(runs) / (len(runs) + len(query_runs(filters={'gradient_method': method, 'status': 'crashed'})))
    avg_duration = sum(r['duration_seconds'] for r in runs if r['duration_seconds']) / len(runs) if runs else 0

    print(f"{method}: {len(runs)} completed, {success_rate*100:.1f}% success, avg {avg_duration/3600:.1f}h")
```

### Find Runs Without Blog Posts
```python
completed_no_blog = query_runs(
    filters={
        'status': 'completed',
        'min_duration_hours': 2,
        'has_blog_post': False
    },
    order_by='duration_seconds DESC',
    limit=20
)

print(f"Found {len(completed_no_blog)} completed runs without blog posts:")
for run in completed_no_blog:
    print(f"  {run['run_name']} ({run['duration_seconds']/3600:.1f}h)")
    print(f"    Config: {run['config_file_path']}")
    print(f"    W&B: {run['wandb_url']}")
```

### Analyze Crashes by Method
```python
import json
from collections import defaultdict

crashes_by_method = defaultdict(list)
crashed_runs = query_runs(filters={'status': 'crashed'}, limit=200)

for run in crashed_runs:
    method = run['gradient_method'] or 'unknown'
    crashes_by_method[method].append(run)

print("Crashes by gradient method:")
for method, runs in sorted(crashes_by_method.items(), key=lambda x: len(x[1]), reverse=True):
    with_analysis = sum(1 for r in runs if r['crash_analysis_s3_key'])
    print(f"  {method}: {len(runs)} crashes ({with_analysis} with analysis)")
```

## Web UI Integration (Future)

The database can be queried directly from the web UI:

### Option A: Next.js API Route (Direct PostgreSQL)
```typescript
// pages/api/training-runs.ts
import { Pool } from 'pg'

const pool = new Pool({ /* DB config */ })

export default async function handler(req, res) {
  const { status, host, method } = req.query
  const result = await pool.query(`
    SELECT * FROM training_runs
    WHERE ($1::text IS NULL OR status = $1)
      AND ($2::text IS NULL OR host = $2)
      AND ($3::text IS NULL OR gradient_method = $3)
    ORDER BY created_at DESC LIMIT 100
  `, [status, host, method])

  res.json(result.rows)
}
```

### Option B: Python Backend (Flask/FastAPI)
```python
from flask import Flask, jsonify, request
from apis.training_db import query_runs

app = Flask(__name__)

@app.route('/api/runs')
def list_runs():
    filters = {k: v for k, v in request.args.items() if v}
    runs = query_runs(filters=filters, limit=100)
    return jsonify(runs)
```

## Environment Variables

Set in `~/.bashrc`:

```bash
export TRAINING_DB_PATH='/home/ubuntu/mango/data/training_runs.db'
```

## Testing

Run the test suite:

```bash
python3 apis/training_db/test_db.py
```

This tests all operations: insert, update, query, attachments, stats.

## Database Maintenance

### View Database Contents
```bash
sqlite3 /home/ubuntu/mango/data/training_runs.db

-- Show all runs
SELECT run_id, status, gradient_method, duration_seconds/3600.0 as hours
FROM training_runs
ORDER BY created_at DESC
LIMIT 20;

-- Stats by status
SELECT status, COUNT(*) FROM training_runs GROUP BY status;

-- Stats by gradient method
SELECT gradient_method, COUNT(*), AVG(duration_seconds)/3600.0 as avg_hours
FROM training_runs
WHERE status = 'completed'
GROUP BY gradient_method;
```

### Backup Database
```bash
# Backup
cp /home/ubuntu/mango/data/training_runs.db \
   /home/ubuntu/mango/data/training_runs_backup_$(date +%Y%m%d).db

# Restore
cp /home/ubuntu/mango/data/training_runs_backup_20251111.db \
   /home/ubuntu/mango/data/training_runs.db
```

### Migration to PostgreSQL (Future)

When we get RDS permissions:

1. Export SQLite data:
```bash
sqlite3 /home/ubuntu/mango/data/training_runs.db .dump > training_runs.sql
```

2. Import to PostgreSQL:
```bash
psql -h <rds-endpoint> -U trainingadmin -d trainingruns < training_runs.sql
```

3. Update environment variable:
```bash
# In ~/.bashrc, change from SQLite to PostgreSQL
export TRAINING_DB_HOST='rds-endpoint.us-east-2.rds.amazonaws.com'
export TRAINING_DB_PORT='5432'
export TRAINING_DB_NAME='trainingruns'
export TRAINING_DB_USER='trainingadmin'
export TRAINING_DB_PASSWORD='<password>'
```

4. No code changes needed - API is database-agnostic!

## Coexistence with `config_tracking_service.py`

The training database coexists with the existing `config_tracking_service.py`:

- **Old system** (`config_tracking_service.py`): Still works, queries W&B directly
- **New system** (this API): Fast SQL queries, event-driven updates
- **Migration path**: Gradually replace W&B queries with database queries
- **Deprecation**: Once all workflows use database, retire `config_tracking_service.py`

No rush to migrate - both systems work independently.

## Future Enhancements

### Phase 2: Additional Tables
- `training_objectives`: Per-objective final values for easier querying
- `training_scaffolds`: Per-scaffold results
- `training_events`: Timeline of events (launch, start, checkpoints, end)

### Phase 3: Real-Time Updates
- W&B webhook → database updates
- Training heartbeat → periodic status updates
- Checkpoint saves → intermediate metrics

### Phase 4: Analytics
- Aggregate statistics (success rates, avg duration by method)
- Cost tracking (compute hours by instance type)
- Hyperparameter tuning analysis (what works best)

## Troubleshooting

### Database locked error
SQLite has limited concurrency. If you get "database is locked":
- Wait a moment and retry
- Or: Migrate to PostgreSQL for better concurrency

### Missing environment variable
```python
# Error: TRAINING_DB_PATH not set
# Solution:
export TRAINING_DB_PATH='/home/ubuntu/mango/data/training_runs.db'
source ~/.bashrc
```

### Database doesn't exist
```python
from apis.training_db import init_db
init_db()  # Creates database and schema
```

## Support

For issues or questions:
1. Check this README
2. Run `python3 apis/training_db/test_db.py` to verify setup
3. Review database schema in `schema.sql`
4. Ask the agent for help!
