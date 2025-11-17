#!/usr/bin/env python3
"""
Automated script to sync training_runs database with W&B run status.

Queries training_runs for runs with status='launched' or 'running',
fetches their actual status from W&B API, and updates the database.

Usage:
    python update_runs_from_wandb.py                    # Update all stale runs
    python update_runs_from_wandb.py --dry-run          # Preview without updating
    python update_runs_from_wandb.py --limit 10         # Only process 10 runs
    python update_runs_from_wandb.py --verbose          # Detailed logging

Can be scheduled via cron:
    */10 * * * * /usr/bin/python3 /home/ubuntu/mangodb/scripts/update_runs_from_wandb.py >> /tmp/update_runs.log 2>&1
"""

import sys
import os
import argparse
from datetime import datetime
from pathlib import Path

# Add paths
sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, '/home/ubuntu/mango')

from training_db.core import get_connection, update_run_status
from apis.our_wandb.core import _get_wandb_config
import wandb


def query_stale_runs(limit=None):
    """
    Query runs that need status/history updates.

    Returns runs that either:
    1. Are currently running (need latest data)
    2. Don't have history yet (need backfill)
    3. Have status='launched' (need initial sync)
    """
    with get_connection() as conn:
        cursor = conn.cursor()

        query = """
            SELECT run_id, run_name, wandb_run_id, status, created_at
            FROM training_runs
            WHERE
                status = 'running'  -- Always update running runs
                OR status = 'launched'  -- Need initial sync
                OR (status = 'not_running' AND history_json IS NULL)  -- Need backfill
            ORDER BY created_at DESC
        """

        if limit:
            query += f" LIMIT {limit}"

        cursor.execute(query)
        rows = cursor.fetchall()

        # Convert Row objects to dicts
        return [dict(row) for row in rows]


def find_wandb_run(api, run_name, entity, project):
    """
    Find W&B run by name.

    Returns: wandb.apis.public.Run or None
    """
    try:
        # Search for runs with this name
        runs = list(api.runs(f"{entity}/{project}", filters={"display_name": run_name}))

        if runs:
            # Return most recent if multiple
            return runs[0]

        return None
    except Exception as e:
        print(f"  Error searching W&B for {run_name}: {e}", file=sys.stderr)
        return None


def map_wandb_state_to_db_status(wandb_state):
    """
    Map W&B run state to database status.

    Simple binary model: either 'running' or 'not_running'.
    For experiments of indeterminate time that are manually stopped when
    asymptotes are reached, 'crashed/failed/finished' distinctions are meaningless.
    """
    if wandb_state == 'running':
        return 'running'
    else:
        # Everything else (finished, failed, crashed, killed, preempted) is just 'not_running'
        return 'not_running'


def extract_wandb_data(run):
    """Extract relevant data from W&B run object."""
    runtime_seconds = run.summary.get("_runtime", 0)

    data = {
        'wandb_run_id': run.id,
        'wandb_url': run.url,
        'status': map_wandb_state_to_db_status(run.state),
        'duration_seconds': int(runtime_seconds) if runtime_seconds else None,
    }

    # Parse timestamps if available
    if hasattr(run, 'created_at') and run.created_at:
        # W&B API returns ISO string already
        if isinstance(run.created_at, str):
            data['started_at'] = run.created_at
        else:
            data['started_at'] = run.created_at.isoformat() + 'Z'

    # For non-running runs, use current time as ended_at
    if run.state != 'running':
        data['ended_at'] = datetime.utcnow().isoformat() + 'Z'

    # Extract final metrics
    if run.state == 'finished' and run.summary:
        # Get summary dict (final metrics)
        summary_dict = dict(run.summary)
        # Remove W&B internal keys
        final_metrics = {k: v for k, v in summary_dict.items() if not k.startswith('_')}
        if final_metrics:
            data['final_metrics_json'] = final_metrics

    # Extract full history (time-series metrics)
    # Fetch for ALL runs (running or not) - training data is always valid and valuable
    # Runs are manually killed when asymptotes are reached, so there's no "completion" signal
    try:
        # Fetch all history (scan_history() streams, doesn't load all at once)
        history = list(run.scan_history())

        # Convert to dictionary keyed by metric name
        # Format: {'objective_COMT': [0.45, 0.47, ...], 'loss': [1.2, 1.1, ...], '_step': [0, 1, 2, ...]}
        if history:
            history_dict = {}

            # Extract all keys from first step
            all_keys = set()
            for step in history:
                all_keys.update(step.keys())

            # Build time-series for each metric
            for key in all_keys:
                history_dict[key] = [step.get(key) for step in history]

            data['history_json'] = history_dict
            print(f"  Fetched {len(history)} steps × {len(all_keys)} metrics")
    except Exception as e:
        print(f"  Warning: Could not fetch history: {e}")

    return data


def update_run(run_id, wandb_data, dry_run=False, verbose=False):
    """Update database with W&B data."""
    status = wandb_data['status']

    if dry_run:
        print(f"  [DRY RUN] Would update {run_id}:")
        print(f"    status: {status}")
        print(f"    wandb_run_id: {wandb_data.get('wandb_run_id')}")
        print(f"    duration: {wandb_data.get('duration_seconds')}s")
        return

    # Update database
    update_run_status(run_id, status, **{k: v for k, v in wandb_data.items() if k != 'status'})

    if verbose:
        print(f"  Updated {run_id}: {status}, {wandb_data.get('duration_seconds')}s")


def mark_stale_launched_as_not_running(run_id, created_at, dry_run=False):
    """Mark old 'launched' runs as 'not_running' if not found in W&B."""
    # Parse created_at
    created_dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
    age_hours = (datetime.now(created_dt.tzinfo) - created_dt).total_seconds() / 3600

    # If run is >2 hours old and still "launched", it never started
    if age_hours > 2:
        if dry_run:
            print(f"  [DRY RUN] Would mark as 'not_running' (launched {age_hours:.1f}h ago, never started)")
            return True
        else:
            update_run_status(run_id, 'not_running')
            print(f"  Marked as 'not_running' (launched {age_hours:.1f}h ago, never started in W&B)")
            return True

    return False


def main():
    parser = argparse.ArgumentParser(description='Sync training_runs DB with W&B')
    parser.add_argument('--dry-run', action='store_true', help='Preview without updating')
    parser.add_argument('--limit', type=int, help='Only process N runs')
    parser.add_argument('--verbose', action='store_true', help='Detailed logging')
    parser.add_argument('--no-mark-stale', action='store_true', help='Do not mark old launched runs as failed')
    args = parser.parse_args()

    print(f"[{datetime.now().isoformat()}] Starting update_runs_from_wandb.py")

    # Get W&B config
    config = _get_wandb_config()
    entity = config['entity']
    project = config['project']

    if not config['api_key']:
        print("ERROR: WANDB_API_KEY not set in environment", file=sys.stderr)
        sys.exit(1)

    # Initialize W&B API
    api = wandb.Api()

    # Query stale runs
    stale_runs = query_stale_runs(limit=args.limit)
    print(f"Found {len(stale_runs)} runs to process")

    if not stale_runs:
        print("No runs need updating")
        return

    # Process each run
    updated_count = 0
    not_found_count = 0
    marked_failed_count = 0
    error_count = 0

    for idx, db_run in enumerate(stale_runs, 1):
        run_id = db_run['run_id']
        run_name = db_run['run_name']
        wandb_run_id = db_run['wandb_run_id']
        created_at = db_run['created_at']

        print(f"\n[{idx}/{len(stale_runs)}] Processing {run_id} (name: {run_name})")

        try:
            # Get W&B run
            if wandb_run_id:
                # Query by ID if we have it
                wandb_run = api.run(f"{entity}/{project}/{wandb_run_id}")
            elif run_name:
                # Search by name
                wandb_run = find_wandb_run(api, run_name, entity, project)
                if not wandb_run:
                    print(f"  W&B run not found for name: {run_name}")
                    not_found_count += 1

                    # Mark stale "launched" runs as not_running
                    if not args.no_mark_stale:
                        if mark_stale_launched_as_not_running(run_id, created_at, dry_run=args.dry_run):
                            marked_failed_count += 1

                    continue
            else:
                print(f"  ERROR: No wandb_run_id or run_name for {run_id}")
                error_count += 1
                continue

            # Extract W&B data
            wandb_data = extract_wandb_data(wandb_run)

            # Update database
            update_run(run_id, wandb_data, dry_run=args.dry_run, verbose=args.verbose)
            updated_count += 1

        except Exception as e:
            print(f"  ERROR processing {run_id}: {e}", file=sys.stderr)
            error_count += 1
            continue

    # Summary
    print(f"\n{'[DRY RUN] ' if args.dry_run else ''}Summary:")
    print(f"  Updated from W&B: {updated_count}")
    print(f"  Marked as failed (stale launched): {marked_failed_count}")
    print(f"  Not found in W&B: {not_found_count - marked_failed_count}")
    print(f"  Errors: {error_count}")
    print(f"[{datetime.now().isoformat()}] Finished")


if __name__ == '__main__':
    main()
