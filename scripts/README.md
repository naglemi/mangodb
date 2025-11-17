# mangodb Scripts

## update_runs_from_wandb.py

Automatically syncs training_runs database with W&B run status.

### Purpose

When training runs are launched, they're added to the database with `status='launched'`. However, the database doesn't automatically update when:
- Runs start training (should be `status='running'`)
- Runs complete (should be `status='completed'`)
- Runs fail (should be `status='failed'` or `status='crashed'`)
- Runs never start (should be marked `status='failed'` after >2 hours)

This script queries the database for stale runs, fetches their actual status from W&B, and updates the database.

### Usage

```bash
# Update all stale runs
python update_runs_from_wandb.py

# Preview without updating (dry-run)
python update_runs_from_wandb.py --dry-run

# Only process 10 runs
python update_runs_from_wandb.py --limit 10

# Verbose logging
python update_runs_from_wandb.py --verbose

# Don't mark old "launched" runs as failed
python update_runs_from_wandb.py --no-mark-stale
```

### Scheduling via Cron

Recommended: Run every 10-15 minutes to keep database current.

```bash
# Add to crontab
crontab -e

# Add this line (runs every 10 minutes)
*/10 * * * * /usr/bin/python3 /home/ubuntu/mangodb/scripts/update_runs_from_wandb.py >> /tmp/update_runs.log 2>&1
```

### What It Does

1. **Queries database** for runs with `status IN ('launched', 'running')`
2. **Searches W&B** for matching runs (by wandb_run_id or run_name)
3. **Extracts W&B data**: state, timestamps, runtime, final metrics
4. **Updates database** with: wandb_run_id, wandb_url, status, duration_seconds, started_at, ended_at, final_metrics_json
5. **Marks stale runs** as failed: If run is >2 hours old and not found in W&B, marks as `status='failed'`

### W&B State Mapping

| W&B State | Database Status |
|-----------|-----------------|
| running   | running         |
| finished  | completed       |
| failed    | failed          |
| crashed   | crashed         |
| killed    | crashed         |
| preempted | crashed         |

### Requirements

- W&B API key in environment: `WANDB_API_KEY`
- Python packages: wandb, sqlite3
- Database at: `/home/ubuntu/mango/data/training_runs.db`

### Output

```
[2025-11-17T00:07:22] Starting update_runs_from_wandb.py
Found 37 runs to process

Processing deco_hop_bs96_imtlg_i-0b8911b7a2371d114 (name: deco_hop_bs96_imtlg_i-0b8911b7a2371d114)
  W&B run not found for name: deco_hop_bs96_imtlg_i-0b8911b7a2371d114
  Marked as 'failed' (launched 98.5h ago, never started in W&B)

...

Summary:
  Updated from W&B: 0
  Marked as failed (stale launched): 36
  Not found in W&B: 0
  Errors: 1
[2025-11-17T00:07:28] Finished
```

## cleanup_orphaned_runs.py

Marks runs as 'crashed' if their EC2 instances are terminated.

(Existing script - run alongside update_runs_from_wandb.py)
