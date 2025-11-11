# Comprehensive W&B Storage Plan

## Problem Statement

W&B runs have **~149 summary keys** and **~149 history keys** with significant overlap. We need to store:

1. **Summary** - Final values at end of run (149 keys)
   - Final aggregated metrics (max/min/mean/std)
   - Git metadata (branch, commit, message, dirty status)
   - User experiment tracking fields
   - Final objective scores

2. **History** - Time series during training (149 keys)
   - Per-step metrics progression
   - Per-layer gradients (NOT in summary)
   - Step-by-step objective values
   - Training dynamics

3. **Config** - All config parameters (~50-100 keys)
   - Training hyperparameters
   - Model architecture settings
   - Reward function configuration
   - Multi-objective settings

**Total**: ~300-400 unique attributes per run

## Current Schema (v2) - Status

### ✅ What We're Already Storing

```sql
-- training_runs table
config_json TEXT              -- Full YAML config (~50-100 attrs)
final_metrics_json TEXT       -- Full W&B summary (~149 attrs)

-- 20 extracted columns for fast queries
batch_size, learning_rate, gradient_method, etc.
```

**This is GOOD!** We're already storing ALL summary data in `final_metrics_json`.

### ❌ What We're MISSING

**W&B History** - Time series data NOT stored anywhere currently

Example of what's lost:
```python
# We store final value:
summary['general_prop/logp_mean'] = 0.456

# But we DON'T store progression:
history['general_prop/logp_mean'] = [0.1, 0.2, 0.3, 0.4, 0.45, 0.456]
```

This means we can't:
- Plot training curves
- Detect when model plateaued
- Analyze training dynamics
- Debug unstable training
- Identify when objectives diverged

## Solution: Add History Storage

### Option 1: Store Full History in JSON (SIMPLE)

Add one column to `training_runs` table:

```sql
ALTER TABLE training_runs ADD COLUMN history_json TEXT;
```

**Pros:**
- Simple implementation
- Preserves ALL history data
- No schema changes needed for new metrics
- Fast to implement

**Cons:**
- Large storage (history can be 100+ steps × 149 keys)
- Queries on history require JSON parsing
- Can't easily filter by "runs where loss increased at step 50"

**Storage estimate:**
- 100 steps × 149 keys × ~20 bytes/value = ~300KB per run
- 1000 runs = ~300MB (manageable)

### Option 2: Dedicated History Table (QUERYABLE)

Create new table for time series:

```sql
CREATE TABLE run_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL,
    step INTEGER NOT NULL,
    metric_name TEXT NOT NULL,
    value REAL,
    timestamp TIMESTAMP,
    FOREIGN KEY (run_id) REFERENCES training_runs(run_id) ON DELETE CASCADE
);

CREATE INDEX idx_history_run_metric ON run_history(run_id, metric_name);
CREATE INDEX idx_history_step ON run_history(step);
```

**Pros:**
- Queryable: "show all runs where loss spiked"
- Efficient for plotting specific metrics
- Can aggregate across runs

**Cons:**
- Complex schema
- Many rows: 100 steps × 149 keys × 1000 runs = 14.9M rows
- Slower inserts
- Need to decide which metrics to store

### Option 3: Hybrid (RECOMMENDED)

**Store full history in JSON + extract key metrics to dedicated table**

```sql
-- Full history as JSON (everything preserved)
ALTER TABLE training_runs ADD COLUMN history_json TEXT;

-- Critical metrics in queryable table (for plotting/analysis)
CREATE TABLE run_history_key_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL,
    step INTEGER NOT NULL,
    -- Key metrics we query often
    loss REAL,
    grad_norm REAL,
    learning_rate REAL,
    -- Per-objective scores (JSON array)
    objective_scores_json TEXT,
    timestamp TIMESTAMP,
    FOREIGN KEY (run_id) REFERENCES training_runs(run_id) ON DELETE CASCADE
);
```

**Why hybrid:**
- Full history preserved in JSON (nothing lost)
- Fast queries on common metrics (loss, grad_norm)
- Reasonable storage (only ~10 metrics per step in table)
- Can add more extracted metrics later

## Recommended Implementation (Phase 1)

### Step 1: Add history_json Column

```sql
ALTER TABLE training_runs ADD COLUMN history_json TEXT;
```

This stores EVERYTHING from W&B history as JSON.

### Step 2: Update Completion Handler

When training completes (or crashes after some steps):

```python
from training_db import update_run_status
import wandb

# Fetch full summary AND history
summary = wandb.run.summary._json_dict
history = wandb.run.history()  # Returns pandas DataFrame

# Convert history to JSON
history_dict = {}
for column in history.columns:
    history_dict[column] = history[column].tolist()

# Update database with EVERYTHING
update_run_status(
    run_id=run_id,
    status='completed',
    final_metrics_json=summary,      # 149 summary keys
    history_json=history_dict,        # 149 history keys × N steps
    ended_at=datetime.utcnow(),
    duration_seconds=int(time.time() - start_time)
)
```

### Step 3: Query Interface

```python
# Get full history for a run
run = get_run('mgda_test_001')
history = json.loads(run['history_json'])

# Plot training curve
import matplotlib.pyplot as plt
plt.plot(history['_step'], history['train/loss'])
plt.show()

# Find when loss plateaued
loss_values = history['train/loss']
plateau_step = detect_plateau(loss_values)
```

## Data Capture Points

### When to Save History

**Option A: On Completion Only**
- Fetch history from W&B API when training completes
- Pro: Simple, one-time fetch
- Con: If training crashes, history might be incomplete

**Option B: Periodic Updates**
- Save history checkpoint every N steps during training
- Pro: Preserved even if training crashes
- Con: More complex, more API calls

**Recommended: Option A** (fetch on completion/crash)
- W&B preserves history even if training crashes
- Can fetch via streaming logs if needed
- Simpler implementation

### Integration Point

**Location**: train.py completion handler (NEW - needs to be added)

```python
# At end of train.py (after trainer.train() completes)
try:
    import sys
    sys.path.insert(0, '/home/ubuntu/mangodb')
    from training_db import update_run_status
    import wandb

    run_id = os.environ.get('RUN_ID')
    if run_id:
        # Fetch summary
        summary = wandb.run.summary._json_dict

        # Fetch history
        history_df = wandb.run.history()
        history_dict = {col: history_df[col].tolist() for col in history_df.columns}

        # Update database with EVERYTHING
        update_run_status(
            run_id=run_id,
            status='completed',
            final_metrics_json=summary,
            history_json=history_dict,
            ended_at=datetime.utcnow(),
            total_training_steps=len(history_df)
        )

        print(f"✓ Saved {len(summary)} summary metrics and {len(history_dict)} history metrics")
except Exception as e:
    print(f"Warning: Could not save W&B data to database: {e}")
```

## Storage Estimates

### Per Run
- Config JSON: ~10KB (50-100 keys)
- Summary JSON: ~30KB (149 keys)
- History JSON: ~300KB (149 keys × 100 steps)
- **Total per run: ~340KB**

### Scale
- 100 runs: ~34MB
- 1,000 runs: ~340MB
- 10,000 runs: ~3.4GB

**SQLite can handle this easily.** PostgreSQL migration recommended at >10K runs.

## Git Metadata

Summary includes critical git metadata:
```json
{
  "git_branch": "main",
  "git_commit": "a135c627",
  "git_commit_message": "Update database imports to use mangodb module",
  "git_dirty": false
}
```

This is already captured in `final_metrics_json` ✓

## Implementation Checklist

### Phase 1: Basic History Storage (HIGH PRIORITY)
- [ ] Add `history_json` column to `training_runs` table
- [ ] Update `update_run_status()` to accept `history_json` parameter
- [ ] Add completion handler to train.py
- [ ] Test with real training run
- [ ] Document history query patterns

### Phase 2: Queryable Key Metrics (MEDIUM PRIORITY)
- [ ] Create `run_history_key_metrics` table
- [ ] Extract loss, grad_norm, learning_rate per step
- [ ] Add plotting utilities
- [ ] Build training curve visualization

### Phase 3: Analysis Tools (LOW PRIORITY)
- [ ] Plateau detection algorithms
- [ ] Training instability detection
- [ ] Objective divergence analysis
- [ ] Hyperparameter sensitivity analysis

## Updated Schema (v2.1)

```sql
-- Add to existing training_runs table
ALTER TABLE training_runs ADD COLUMN history_json TEXT;

-- Optional: Queryable key metrics (Phase 2)
CREATE TABLE run_history_key_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL,
    step INTEGER NOT NULL,
    loss REAL,
    grad_norm REAL,
    learning_rate REAL,
    timestamp TIMESTAMP,
    FOREIGN KEY (run_id) REFERENCES training_runs(run_id) ON DELETE CASCADE
);
```

## Example Queries

### Find Runs That Plateaued Early
```python
runs = query_runs(filters={'status': 'completed'})
for run in runs:
    history = json.loads(run['history_json'])
    loss = history.get('train/loss', [])
    if len(loss) > 50:
        early_loss = np.mean(loss[10:20])
        late_loss = np.mean(loss[40:50])
        if abs(early_loss - late_loss) < 0.01:
            print(f"Run {run['run_id']} plateaued early")
```

### Compare Training Dynamics
```python
mgda_runs = query_runs(filters={'gradient_method': 'mgda'})
pcgrad_runs = query_runs(filters={'gradient_method': 'pcgrad'})

# Plot average loss curves
for runs, label in [(mgda_runs, 'MGDA'), (pcgrad_runs, 'PCGrad')]:
    avg_loss = []
    for run in runs:
        history = json.loads(run['history_json'])
        avg_loss.append(history['train/loss'])

    plt.plot(np.mean(avg_loss, axis=0), label=label)

plt.legend()
plt.show()
```

## Summary

**Current Status:**
✅ Config stored (config_json)
✅ Summary stored (final_metrics_json)
❌ History NOT stored

**Next Steps:**
1. Add `history_json` column to database
2. Update `update_run_status()` API
3. Add completion handler to train.py to fetch and save history
4. Test with real training run

**This will give us COMPLETE W&B data storage** - nothing will be lost.
