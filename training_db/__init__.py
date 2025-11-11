"""
Training Runs Database API

Provides a centralized SQL database for tracking all training runs across the system.

Usage:
    from apis.training_db import insert_run, update_run_status, attach_blog_post
    from apis.training_db import insert_objective, query_runs_by_objectives

    # At launch
    insert_run(run_id, wandb_run_id=None, config_dict=config, ...)
    insert_objective(run_id, 'COMT_activity', weight=2.0, direction='maximize')

    # During training
    update_run_status(run_id, 'running', wandb_run_id=wandb.run.id)

    # On completion
    update_objective_metric(run_id, 'COMT_activity', 'raw_mean', 0.856)

    # On crash
    attach_crash_data(run_id, error_s3_key, crash_report_s3_key, analysis_s3_key)

    # After blog post
    attach_blog_post(run_id, blog_url)

    # Query by objectives
    runs = query_runs_by_objectives({'COMT_activity': {'min': 0.8}})
"""

from .core import (
    init_db,
    insert_run,
    update_run_status,
    get_run,
    query_runs,
    attach_blog_post,
    attach_crash_data,
    attach_conversation,
    get_stats,
)

from .objectives import (
    insert_objective,
    update_objective_metric,
    get_run_objectives,
    query_runs_by_objectives,
    get_objective_statistics,
    compare_gradient_methods,
    delete_run_objectives,
)

__all__ = [
    # Core functions
    'init_db',
    'insert_run',
    'update_run_status',
    'get_run',
    'query_runs',
    'attach_blog_post',
    'attach_crash_data',
    'attach_conversation',
    'get_stats',
    # Objectives functions
    'insert_objective',
    'update_objective_metric',
    'get_run_objectives',
    'query_runs_by_objectives',
    'get_objective_statistics',
    'compare_gradient_methods',
    'delete_run_objectives',
]
