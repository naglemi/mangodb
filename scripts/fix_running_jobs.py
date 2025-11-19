#!/usr/bin/env python
"""Fix the 2 running jobs by finding their W&B IDs"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path.home() / "mango" / "apis"))
sys.path.insert(0, str(Path.home() / "mangodb"))

from our_wandb.core import _get_wandb_config
from training_db.core import get_connection, update_run_status
import wandb

config = _get_wandb_config()
ENTITY = config['entity']
PROJECT = config['project']

# Get recent runs from W&B
api = wandb.Api(timeout=60)
print("Fetching recent runs from W&B...")
recent_runs = list(api.runs(f"{ENTITY}/{PROJECT}", order="-created_at"))[:50]

print(f"Got {len(recent_runs)} recent runs\n")

# Database runs to fix
runs_to_fix = [
    "perindopril_mpo_i-07eec3b992edddacf",
    "perindopril_mpo_bs96_mgda_i-0418b390d1e718838"
]

for db_run_id in runs_to_fix:
    print(f"Finding W&B run for: {db_run_id}")

    # Extract config prefix (everything before the instance ID)
    parts = db_run_id.rsplit('_i-', 1)
    if len(parts) == 2:
        config_prefix = parts[0]
        print(f"  Config prefix: {config_prefix}")

        # Find matching W&B run
        matches = []
        for run in recent_runs:
            if config_prefix in run.name and run.state == 'running':
                matches.append(run)
                print(f"    Candidate: {run.name} (ID: {run.id}, State: {run.state})")

        if matches:
            # Use the first (most recent) match
            wandb_run = matches[0]
            print(f"  ✅ Selected: {wandb_run.name}")
            print(f"     W&B ID: {wandb_run.id}")
            print(f"     URL: {wandb_run.url}")

            # Update database
            update_run_status(
                run_id=db_run_id,
                status='running',
                wandb_run_id=wandb_run.id,
                wandb_url=wandb_run.url,
                run_name=wandb_run.name
            )
            print(f"  ✅ Updated database\n")
        else:
            print(f"  ❌ No matches found\n")
    else:
        print(f"  ❌ Could not parse run_id\n")
