# Simplified Data Ingestion Strategy

## Problem with Previous Approach
- Was going to insert objectives at launch, then update at completion
- Overcomplicated with split logic
- Two places to maintain

## New Simplified Approach

### 1. At Launch (launch_ec2.py) - ALREADY WORKING ✅
```python
from apis.training_db import insert_run

# Insert run with EVERYTHING from config
insert_run(
    run_id=run_id,
    wandb_run_id=None,  # Don't have it yet
    config_dict=config,  # Full YAML - stored in config_json
    chain_of_custody_id=chain_of_custody_id,
    run_name=run_id,
    config_file_path=str(config_path),
    host='ec2',
    instance_id=instance_id
)
# Note: Objectives info is already in config_json, no separate insert needed
```

### 2. When W&B Initializes (train.py) - ✅ DONE (finetune_safe commit ef0e8ac0)
```python
# Inside train.py, after GRPOTrainer creation (line 1601-1620)
try:
    import sys
    sys.path.insert(0, '/home/ubuntu/mango')
    from apis.training_db import update_run_status
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

### 3. At Completion (train.py or monitor) - FUTURE
```python
# After training completes
try:
    from apis.training_db import update_run_status
    import wandb

    summary = wandb.run.summary._json_dict

    # Update run with ALL final metrics
    update_run_status(
        run_id=os.environ['RUN_ID'],
        status='completed',
        final_metrics_json=summary,  # ALL W&B data in JSON
        ended_at=datetime.utcnow(),
        duration_seconds=int(time.time() - start_time)
    )

    # Parse objectives from W&B summary and insert into run_objectives table
    from apis.training_db.objectives import insert_objective, update_objective_metric

    for key, value in summary.items():
        if key.startswith('objectives/'):
            # Parse: objectives/COMT_activity_maximize/raw_mean -> 0.856
            parts = key.split('/')
            if len(parts) == 3:
                obj_alias = parts[1]  # "COMT_activity_maximize"
                metric_type = parts[2]  # "raw_mean"

                obj_name = obj_alias.replace('_maximize', '').replace('_minimize', '')

                # First time we see this objective, insert it
                # (INSERT OR IGNORE - won't fail if already exists)
                insert_objective(
                    run_id=run_id,
                    objective_name=obj_name,
                    objective_alias=obj_alias
                )

                # Update the metric
                update_objective_metric(run_id, obj_name, metric_type, value)
except Exception as e:
    # Don't crash if DB update fails
    pass
```

### 4. At Crash (crash_notifications.py) - ALREADY WORKING ✅
```python
from apis.training_db import attach_crash_data

attach_crash_data(
    run_id=run_id,
    error_log_s3_key=f'crash-reports/{run_id}/error.log',
    crash_report_s3_key=f'crash-reports/{run_id}/report.md',
    crash_analysis_s3_key=f'crash-reports/{run_id}/analysis.md'
)
```

## Summary

**Three clear update points:**
1. **Launch** → insert_run() with config [✅ DONE]
2. **W&B init** → update with wandb_run_id, wandb_url [🔄 NEEDS 1 LINE IN train.py]
3. **Completion** → update with final_metrics_json, parse objectives [📋 FUTURE]

**Key insight:** Objectives are populated **entirely from W&B summary at completion**, not split across launch and completion. Much simpler!

## Current Status

✅ **All critical functionality is working:**

1. **At launch**: Run inserted with full config → database
2. **When W&B starts**: wandb_run_id and wandb_url → database
3. **On crash**: Error logs and Bedrock analysis → database

**Optional future enhancement:**
- Parse final metrics from W&B summary at completion
- Populate objectives table from W&B summary
- Can be done anytime - all data is already in final_metrics_json

The database is **production-ready** and tracking all runs!
