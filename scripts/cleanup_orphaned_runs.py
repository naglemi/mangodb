#!/usr/bin/python3.10
"""
Cleanup Orphaned Training Runs

This script checks for runs in "launched" or "running" status whose EC2 instances
are terminated. It updates them to "crashed" status.

This is a backup mechanism for cases where:
- Training crashes before W&B initializes
- EC2 instance terminates before update_run_status() is called
- Network issues prevent database updates

Run periodically via cron:
    */5 * * * * /home/ubuntu/mangodb/scripts/cleanup_orphaned_runs.py >> /home/ubuntu/mangodb/scripts/cleanup.log 2>&1
"""

import sys
import os
from datetime import datetime

# Add mangodb to path
sys.path.insert(0, '/home/ubuntu/mangodb')

try:
    from training_db import query_runs, update_run_status
    import boto3
except ImportError as e:
    print(f"ERROR: Missing dependencies: {e}")
    print("Make sure you're running with correct Python environment")
    sys.exit(1)


def cleanup_orphaned_runs():
    """Check for runs with terminated instances and update database."""

    print(f"\n{'='*60}")
    print(f"Orphaned Run Cleanup - {datetime.utcnow().isoformat()}")
    print(f"{'='*60}")

    # Get all runs still in launched or running status
    try:
        launched_runs = query_runs(filters={'status': 'launched'})
        running_runs = query_runs(filters={'status': 'running'})
        active_runs = launched_runs + running_runs
    except Exception as e:
        print(f"ERROR: Could not query database: {e}")
        return

    if not active_runs:
        print("No active runs found in database")
        return

    print(f"Found {len(active_runs)} active runs to check")
    print(f"  - Launched: {len(launched_runs)}")
    print(f"  - Running: {len(running_runs)}")

    # Initialize EC2 client
    try:
        ec2 = boto3.client('ec2', region_name=os.environ.get('AWS_DEFAULT_REGION', 'us-east-2'))
    except Exception as e:
        print(f"ERROR: Could not create EC2 client: {e}")
        return

    # Check each run's instance status
    updated_count = 0
    for run in active_runs:
        instance_id = run.get('instance_id')
        run_id = run['run_id']
        status = run['status']

        if not instance_id:
            print(f"  {run_id}: No instance_id, skipping")
            continue

        # Skip Expanse runs (they have different instance_id format)
        if run.get('host') == 'expanse':
            continue

        # Check if instance exists and its state
        try:
            response = ec2.describe_instances(InstanceIds=[instance_id])

            if not response['Reservations']:
                # Instance doesn't exist = definitely terminated
                print(f"  {run_id}: Instance {instance_id} not found (terminated)")
                state = 'terminated'
            else:
                state = response['Reservations'][0]['Instances'][0]['State']['Name']
                print(f"  {run_id}: Instance {instance_id} state = {state}")

            # Update database if instance is dead
            if state in ['terminated', 'shutting-down', 'stopped']:
                print(f"    → Updating to crashed status")
                update_run_status(
                    run_id,
                    'crashed',
                    ended_at=datetime.utcnow()
                )
                updated_count += 1

        except ec2.exceptions.ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            if error_code == 'InvalidInstanceID.NotFound':
                # Instance doesn't exist
                print(f"  {run_id}: Instance {instance_id} not found (terminated)")
                print(f"    → Updating to crashed status")
                update_run_status(
                    run_id,
                    'crashed',
                    ended_at=datetime.utcnow()
                )
                updated_count += 1
            else:
                print(f"  {run_id}: AWS error checking instance: {e}")

        except Exception as e:
            print(f"  {run_id}: Unexpected error: {e}")

    print(f"\n{'='*60}")
    print(f"Cleanup complete: Updated {updated_count} orphaned runs")
    print(f"{'='*60}\n")


if __name__ == '__main__':
    cleanup_orphaned_runs()
