# Training Data Architecture

## Current State - What We Have

### SQL Database (mangodb)
**Location**: `/home/ubuntu/mango/data/training_runs.db`

**Stores**:
- Run metadata (run_id, wandb_run_id, wandb_url, status, timestamps)
- Config/hyperparameters (batch_size, lr, gradient_method, etc.)
- Chain of custody tracking
- Final metrics summary (final_metrics_json field) - **SCALAR VALUES ONLY**

**Does NOT store**:
- Time-series metrics (objective values over training steps)
- Histograms or other complex metrics
- Full training curves

### W&B (Weights & Biases)
**Location**: Cloud (wandb.ai)

**Stores EVERYTHING**:
- Full time-series metrics (objective_COMT, objective_DRD3, etc. at every logged step)
- Histograms (gradients, activations, etc.)
- Scalars (loss, reward, etc.)
- System metrics (GPU memory, CPU usage)
- Artifacts (model checkpoints, plots)
- Full config
- Run metadata

## The Answer to Your Questions

### 1. "What about objective metrics as vectors (one value per step)?"

**These live in W&B ONLY. They are NOT in the SQL database.**

When you want training curves/time-series data, you query W&B directly:

```python
from apis.our_wandb import get_run_by_id

run_data = get_run_by_id('abc123def')
history = run_data['history']  # List of dicts, one per logged step

# Each step has all metrics logged at that step:
# history[0] = {'_step': 0, 'objective_COMT': 0.45, 'objective_DRD3': -8.2, ...}
# history[1] = {'_step': 1, 'objective_COMT': 0.47, 'objective_DRD3': -8.1, ...}
```

### 2. "Do we have to manually retrieve those?"

**YES - time-series metrics are retrieved on-demand from W&B.**

The SQL database is for:
- Fast queries ("show me all runs with MGDA gradient method")
- Status tracking ("which runs are currently running?")
- Metadata lookups ("what config did run X use?")

W&B is for:
- Full training curves
- Detailed analysis
- Plotting objective trajectories
- Comparing methods over time

### 3. "When we update, do we make sure they are included in SQL DB?"

**NO - and we shouldn't!**

Reasons:
1. **Volume**: A 10-hour run logging every 10 steps = 3600 steps × 20 objectives = 72,000 values
   - Storing in SQLite would be massive and slow
2. **Query patterns**: When analyzing training curves, you want ALL the data points for ONE run
   - SQL databases are bad at this (would need 3600 separate rows or giant JSON blobs)
   - W&B is optimized for this exact use case
3. **Histograms**: These are matrices (e.g., 100 bins × N layers). SQLite can't efficiently store/query these
4. **Redundancy**: W&B already has all this data in optimized format

## What Gets Stored Where

### SQL Database (mangodb)
```
run_id: deco_hop_bs96_mgda_i-0abc123
wandb_run_id: xyz789
status: not_running
duration_seconds: 14523
batch_size: 96
gradient_method: mgda
num_objectives: 4
final_metrics_json: {"objective_COMT_mean": 0.82, "objective_DRD3_mean": -7.5}
```

### W&B
```
Run: xyz789
History (14523 steps):
  Step 0: {objective_COMT: 0.45, objective_DRD3: -8.2, objective_DRD4: -9.1, ...}
  Step 1: {objective_COMT: 0.46, objective_DRD3: -8.1, objective_DRD4: -9.0, ...}
  ...
  Step 14522: {objective_COMT: 0.82, objective_DRD3: -7.5, objective_DRD4: -6.8, ...}

Histograms:
  gradient_norms (100 bins × 50 layers × 14523 steps)
  
System metrics:
  gpu_memory_mb (every 10 seconds × 10 hours = 3600 values)
```

## Backfill Script - What It Does

**Purpose**: Match old database entries (with synthetic names) to their W&B runs

**What it updates in SQL**:
- wandb_run_id (so we can find the run in W&B)
- wandb_url (direct link to W&B)
- run_name (actual W&B display name)
- status (running/not_running)
- started_at timestamp

**What it does NOT do**:
- Does NOT copy time-series metrics to SQL (they stay in W&B)
- Does NOT copy histograms (they stay in W&B)
- Does NOT copy training curves (they stay in W&B)

**How often to run it**: 
- **ONE TIME ONLY** - to fix old runs that were launched before our fix
- After the fix (already deployed), new runs automatically update the database when they start
- Backfill was needed because old runs had wrong names in database

## Workflow for Analysis

### Fast Metadata Query (Use SQL)
```python
from training_db import query_runs

# Find all MGDA runs
runs = query_runs(gradient_method='mgda', status='not_running')
```

### Get Training Curves (Use W&B)
```python
from apis.our_wandb import get_run_by_id

for run in runs:
    # Get full history from W&B
    data = get_run_by_id(run['wandb_run_id'])
    history = data['history']
    
    # Plot objectives over time
    comt_values = [step['objective_COMT'] for step in history]
    steps = [step['_step'] for step in history]
    plot(steps, comt_values)
```

## Summary

**SQL Database**: Lightweight metadata for fast queries and status tracking

**W&B**: Complete training data (time-series, histograms, everything)

**Backfill**: ONE-TIME operation to fix old runs. Not needed going forward.

**Time-series metrics**: ALWAYS retrieved from W&B on-demand. NEVER stored in SQL.
