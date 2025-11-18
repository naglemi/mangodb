"""
W&B Data Synchronization

Syncs training run data from W&B to the local database.
Populates objectives, metrics, and run metadata.
"""

import os
import yaml
import wandb
from pathlib import Path
from typing import Dict, List, Optional

from .objectives import insert_objective, update_objective_metric


def parse_config_objectives(config_path: str) -> List[Dict]:
    """
    Parse objectives from a config file

    Args:
        config_path: Path to YAML config file

    Returns:
        List of objective dicts with name, alias, direction, weight
    """
    try:
        # Handle both absolute and relative paths
        if not config_path.startswith('/'):
            config_path = f"/home/ubuntu/finetune_safe/{config_path}"

        config_file = Path(config_path)
        if not config_file.exists():
            print(f"Config file not found: {config_path}")
            return []

        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)

        if 'objectives' not in config or not config['objectives']:
            return []

        objectives = []
        for obj in config['objectives']:
            objectives.append({
                'name': obj.get('name'),
                'alias': obj.get('alias'),
                'direction': obj.get('direction'),
                'weight': obj.get('weight', 1.0)
            })

        return objectives
    except Exception as e:
        print(f"Error parsing config {config_path}: {e}")
        return []


def sync_run_objectives_from_config(run_id: str, config_path: str) -> int:
    """
    Sync objectives from config file to database

    Args:
        run_id: Run identifier
        config_path: Path to config file

    Returns:
        Number of objectives inserted
    """
    objectives = parse_config_objectives(config_path)

    if not objectives:
        return 0

    count = 0
    for obj in objectives:
        insert_objective(
            run_id=run_id,
            objective_name=obj['name'],
            objective_alias=obj['alias'],
            weight=obj['weight'],
            direction=obj['direction']
        )
        count += 1

    return count


def sync_run_metrics_from_wandb(run_id: str, wandb_run_id: str) -> int:
    """
    Sync objective metric values from W&B to database

    Args:
        run_id: Run identifier
        wandb_run_id: W&B run ID

    Returns:
        Number of metrics updated
    """
    try:
        # Get run data with metrics directly from W&B API
        entity = os.environ.get('WANDB_ENTITY', 'michael-nagle-lieber-institute-for-brain-development-joh')
        project = os.environ.get('WANDB_PROJECT', 'cluster-pareto-grpo-safe')

        api = wandb.Api()
        run = api.run(f"{entity}/{project}/{wandb_run_id}")

        # Get metrics history
        history = run.history(samples=10000)
        if history.empty:
            return 0

        metrics = history.to_dict('records')
        if not metrics or len(metrics) == 0:
            return 0

        # Get the final record (last training step)
        final_record = metrics[-1]

        count = 0

        # Find all objective metrics and update database
        for key, value in final_record.items():
            if key.startswith('objectives/') and '/raw_mean' in key:
                # Extract objective name
                # Format: objectives/osimertinib_phco_dissim_minimize/raw_mean
                # We want: osimertinib_phco_dissim
                parts = key.replace('objectives/', '').split('/')
                if len(parts) >= 2:
                    obj_full_name = parts[0]

                    # Remove _maximize/_minimize suffix to get base name
                    if obj_full_name.endswith('_maximize'):
                        obj_name = obj_full_name.replace('_maximize', '')
                    elif obj_full_name.endswith('_minimize'):
                        obj_name = obj_full_name.replace('_minimize', '')
                    else:
                        obj_name = obj_full_name

                    # Update the metric
                    if value is not None and str(value) != 'nan':
                        update_objective_metric(
                            run_id=run_id,
                            objective_name=obj_name,
                            metric_type='raw_mean',
                            value=float(value)
                        )
                        count += 1

        return count

    except Exception as e:
        print(f"Error syncing metrics from W&B for {run_id}: {e}")
        return 0


def sync_run_complete(run_id: str, wandb_run_id: str, config_path: str) -> Dict:
    """
    Complete sync: objectives from config + metrics from W&B

    Args:
        run_id: Run identifier
        wandb_run_id: W&B run ID
        config_path: Path to config file

    Returns:
        Dict with sync results
    """
    result = {
        'run_id': run_id,
        'objectives_synced': 0,
        'metrics_synced': 0,
        'success': False,
        'error': None
    }

    try:
        # Sync objectives from config
        if config_path:
            result['objectives_synced'] = sync_run_objectives_from_config(run_id, config_path)

        # Sync metrics from W&B
        if wandb_run_id:
            result['metrics_synced'] = sync_run_metrics_from_wandb(run_id, wandb_run_id)

        result['success'] = True

    except Exception as e:
        result['error'] = str(e)

    return result


def get_objectives_display_data(run_id: str, config_path: Optional[str] = None,
                                 wandb_run_id: Optional[str] = None) -> List[Dict]:
    """
    Get objectives for display, with fallback to config and W&B

    This function tries multiple sources:
    1. Database run_objectives table (populated at training time)
    2. Config file (always available if config_path provided)
    3. W&B metrics (if wandb_run_id provided)

    Args:
        run_id: Run identifier
        config_path: Optional path to config file
        wandb_run_id: Optional W&B run ID

    Returns:
        List of objective dicts for display
    """
    from .objectives import get_run_objectives

    # Try database first
    objectives = get_run_objectives(run_id)

    if objectives:
        return objectives

    # If database is empty, try config + W&B
    if config_path:
        config_objs = parse_config_objectives(config_path)

        if not config_objs:
            return []

        # Try to get values from W&B
        if wandb_run_id:
            try:
                entity = os.environ.get('WANDB_ENTITY', 'michael-nagle-lieber-institute-for-brain-development-joh')
                project = os.environ.get('WANDB_PROJECT', 'cluster-pareto-grpo-safe')

                api = wandb.Api()
                run = api.run(f"{entity}/{project}/{wandb_run_id}")

                history = run.history(samples=10000)
                if not history.empty:
                    metrics = history.to_dict('records')
                    if metrics and len(metrics) > 0:
                        final_record = metrics[-1]

                        # Match W&B metrics to config objectives
                        for obj in config_objs:
                            obj_name = obj['name']

                            # Try to find matching metric in W&B data
                            for key, value in final_record.items():
                                if key.startswith('objectives/') and obj_name in key and '/raw_mean' in key:
                                    if value is not None and str(value) != 'nan':
                                        obj['raw_mean'] = float(value)
                                        break
            except:
                pass

        return config_objs

    return []
