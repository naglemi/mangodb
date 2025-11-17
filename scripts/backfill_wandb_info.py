#!/usr/bin/env python3
"""
One-time script to backfill W&B info for runs that were launched before the fix.

This script finds database runs without wandb_run_id and matches them with
actual W&B runs by config prefix and timestamp proximity.
"""
import sys
import os
from pathlib import Path
from datetime import datetime

# Add paths
sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, '/home/ubuntu/mango')

from training_db.core import get_connection, update_run_status
from apis.our_wandb.core import _get_wandb_config
import wandb


def find_wandb_match(api, db_run, entity, project, all_runs):
    """Find matching W&B run for a database entry."""
    run_id = db_run['run_id']
    created_at = datetime.fromisoformat(db_run['created_at'].replace('Z', '+00:00'))
    
    # Extract config prefix from run_id
    # Format: {config}_{instance_id}
    parts = run_id.rsplit('_', 1)
    if len(parts) != 2:
        return None
        
    config_prefix = parts[0]
    
    # Search for runs with matching config prefix and similar timestamp
    matches = []
    for run in all_runs:
        if config_prefix in run.name:
            # Check if created time is close (within 30 minutes)
            run_created = datetime.fromisoformat(run.created_at.replace('Z', '+00:00'))
            time_diff = abs((run_created - created_at).total_seconds())
            if time_diff < 1800:  # Within 30 minutes
                matches.append((run, time_diff))
    
    if matches:
        # Sort by time difference and return best match
        matches.sort(key=lambda x: x[1])
        return matches[0][0]
    
    return None


def main():
    print("="*80)
    print("BACKFILLING W&B INFO FOR OLD RUNS")
    print("="*80)
    
    # Get W&B config
    config = _get_wandb_config()
    entity = config['entity']
    project = config['project']
    
    if not config['api_key']:
        print("ERROR: WANDB_API_KEY not set in environment", file=sys.stderr)
        sys.exit(1)
    
    # Initialize W&B API
    api = wandb.Api()
    
    # Fetch all recent runs from W&B (once, to avoid repeated API calls)
    print("\nFetching runs from W&B...")
    all_runs = list(api.runs(f"{entity}/{project}", order="-created_at"))
    print(f"Fetched {len(all_runs)} runs from W&B")
    
    # Query database for runs without W&B info
    print("\nQuerying database for runs without W&B info...")
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT run_id, run_name, status, created_at
            FROM training_runs
            WHERE wandb_run_id IS NULL
            AND created_at >= datetime('now', '-7 days')
            ORDER BY created_at DESC
        """)
        db_runs = [dict(row) for row in cursor.fetchall()]
    
    print(f"Found {len(db_runs)} database runs to backfill\n")
    
    # Process each run
    matched_count = 0
    not_matched_count = 0
    
    for db_run in db_runs:
        run_id = db_run['run_id']
        print(f"\nProcessing {run_id}...")
        
        try:
            # Find matching W&B run
            wandb_run = find_wandb_match(api, db_run, entity, project, all_runs)
            
            if wandb_run:
                print(f"  ✓ Matched with: {wandb_run.name}")
                print(f"    W&B ID: {wandb_run.id}")
                print(f"    W&B URL: {wandb_run.url}")
                
                # Map W&B state to database status
                # Simple binary model: either 'running' or 'not_running'
                # For experiments of indeterminate time that are manually stopped,
                # crashed/failed/finished distinctions are meaningless
                new_status = 'running' if wandb_run.state == 'running' else 'not_running'
                
                # Update database
                update_run_status(
                    run_id=run_id,
                    status=new_status,
                    wandb_run_id=wandb_run.id,
                    wandb_url=wandb_run.url,
                    run_name=wandb_run.name,
                    started_at=wandb_run.created_at
                )
                print(f"  ✓ Updated database: status={new_status}")
                matched_count += 1
            else:
                print(f"  ✗ No match found in W&B")
                not_matched_count += 1
                
        except Exception as e:
            print(f"  ✗ Error: {e}")
            not_matched_count += 1
    
    # Summary
    print("\n" + "="*80)
    print("BACKFILL COMPLETE")
    print("="*80)
    print(f"Matched and updated: {matched_count}")
    print(f"Not matched: {not_matched_count}")
    print("="*80)


if __name__ == '__main__':
    main()
