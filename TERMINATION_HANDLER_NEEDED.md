# Critical Gap: Termination Handler for Database Updates

## Problem Discovered

Three runs crashed and the database shows them as "launched" with NO crash data:
- `deco_hop_bs96_mgda_i-0e4a3a096afeba3e4`
- `deco_hop_bs96_pcgrad_i-0fee59edc58cfd038`
- `deco_hop_bs96_imtlg_i-0d8073a02ab10c08e`

### What Happened

1. ✅ `launch_ec2.py` called `insert_run()` - runs recorded as "launched"
2. ❌ Training crashed BEFORE W&B initialized - `update_run_status()` in train.py never reached
3. ❌ `crash_notifications.py` never called - no crash data attached

### Root Cause

**There is NO termination handler that updates the database when EC2 instances terminate!**

Current flow:
```
Launch → insert_run() [✅ WORKS]
  ↓
Training starts → update_run_status('running') [❌ NEVER REACHED IF CRASH EARLY]
  ↓
Training completes → update_run_status('completed') [❌ NEVER REACHED]
  ↓
Crash detected → attach_crash_data() [❌ NEVER CALLED]
```

## Solution: Add Termination Handler

We need a CloudWatch Events rule that triggers when EC2 instances terminate and updates the database.

### Option 1: CloudWatch Events + Lambda (RECOMMENDED)

**CloudWatch Events Rule:**
```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["terminated", "stopping"]
  }
}
```

**Lambda Function:**
```python
import boto3
import sys
sys.path.insert(0, '/mnt/efs/mangodb')  # If using EFS
from training_db import update_run_status, get_run

def handler(event, context):
    instance_id = event['detail']['instance-id']

    # Find run by instance_id
    runs = query_runs(filters={'instance_id': instance_id})
    if not runs:
        return  # Not a training instance

    run = runs[0]

    # If still in "launched" status, it crashed before training started
    if run['status'] == 'launched':
        update_run_status(
            run['run_id'],
            'crashed',
            ended_at=datetime.utcnow(),
            # Try to fetch logs from CloudWatch if available
        )
```

### Option 2: User Data Script (SIMPLER)

Add to EC2 user data script (runs on termination):

```bash
# In launch_ec2.py user data, add trap handler
cat << 'TRAP_HANDLER' >> /tmp/update_db_on_exit.sh
#!/bin/bash
python3 << 'PYEOF'
import sys
import os
sys.path.insert(0, '/home/ubuntu/mangodb')
from training_db import update_run_status, get_run
from datetime import datetime

run_id = os.environ.get('RUN_ID')
if run_id:
    run = get_run(run_id)
    if run and run['status'] == 'launched':
        # Still in launched state = crashed before training started
        update_run_status(
            run_id,
            'crashed',
            ended_at=datetime.utcnow()
        )
        print(f"Updated {run_id} to crashed status")
PYEOF
TRAP_HANDLER

chmod +x /tmp/update_db_on_exit.sh

# Register trap to run on EXIT signal
trap '/tmp/update_db_on_exit.sh' EXIT
```

### Option 3: Periodic Monitor Script (BACKUP)

Run a cron job that checks for instances that are terminated but still show "launched":

```python
# /home/ubuntu/mangodb/scripts/cleanup_orphaned_runs.py
import sys
sys.path.insert(0, '/home/ubuntu/mangodb')
from training_db import query_runs, update_run_status
import boto3
from datetime import datetime, timedelta

# Get all runs still in "launched" status
launched_runs = query_runs(filters={'status': 'launched'})

ec2 = boto3.client('ec2')

for run in launched_runs:
    instance_id = run['instance_id']

    # Check if instance is terminated
    try:
        response = ec2.describe_instances(InstanceIds=[instance_id])
        state = response['Reservations'][0]['Instances'][0]['State']['Name']

        if state in ['terminated', 'shutting-down', 'stopped']:
            # Instance is dead but database still says "launched"
            update_run_status(
                run['run_id'],
                'crashed',
                ended_at=datetime.utcnow()
            )
            print(f"Updated orphaned run: {run['run_id']}")
    except:
        # Instance doesn't exist = definitely crashed
        update_run_status(
            run['run_id'],
            'crashed',
            ended_at=datetime.utcnow()
        )
```

Add to crontab:
```bash
*/5 * * * * python3 /home/ubuntu/mangodb/scripts/cleanup_orphaned_runs.py
```

## Immediate Fix

For the three crashed runs, manually update them:

```python
import sys
sys.path.insert(0, '/home/ubuntu/mangodb')
from training_db import update_run_status
from datetime import datetime

run_ids = [
    'deco_hop_bs96_mgda_i-0e4a3a096afeba3e4',
    'deco_hop_bs96_pcgrad_i-0fee59edc58cfd038',
    'deco_hop_bs96_imtlg_i-0d8073a02ab10c08e'
]

for run_id in run_ids:
    update_run_status(
        run_id,
        'crashed',
        ended_at=datetime.utcnow()
    )
    print(f"✓ Updated {run_id} to crashed")
```

## Recommended Implementation

**Short term (NOW):**
1. Run manual fix script above to update the three runs
2. Implement Option 3 (periodic cleanup script) - simple and works

**Medium term (NEXT WEEK):**
1. Add trap handler (Option 2) to launch_ec2.py user data
2. Test with real training run

**Long term (FUTURE):**
1. Implement CloudWatch Events + Lambda (Option 1)
2. Most robust, handles all cases
3. Can also fetch final logs from CloudWatch and attach to database

## Why This Matters

Without proper termination handling:
- Database shows runs as "launched" forever (wrong status)
- No way to distinguish failed launches from in-progress training
- Stats are wrong (crash rate underreported)
- Can't query "find all runs that crashed during initialization"
- Missing critical debugging information

This is a **critical gap** in the database integration.
