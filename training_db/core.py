"""Core database operations for training runs tracking."""

import sqlite3
import json
import os
from pathlib import Path
from contextlib import contextmanager
from datetime import datetime
from typing import Dict, List, Optional, Any

# Database path (can be overridden via environment variable)
DB_PATH = os.environ.get('TRAINING_DB_PATH', '/home/ubuntu/mango/data/training_runs.db')

# Ensure data directory exists
Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)


@contextmanager
def get_connection():
    """Context manager for database connections."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # Return dicts instead of tuples
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db():
    """Initialize database with schema (idempotent)."""
    schema_path = Path(__file__).parent / 'schema.sql'

    with open(schema_path, 'r') as f:
        schema_sql = f.read()

    with get_connection() as conn:
        conn.executescript(schema_sql)

    print(f"Database initialized at {DB_PATH}")


def insert_run(
    run_id: str,
    wandb_run_id: Optional[str],
    config_dict: Dict[str, Any],
    chain_of_custody_id: Optional[str] = None,
    **kwargs
) -> None:
    """
    Insert new training run (called at launch).

    Args:
        run_id: Unique run identifier (e.g., "config_i-0abc123")
        wandb_run_id: W&B run ID (may be None at launch)
        config_dict: Full config dictionary from YAML
        chain_of_custody_id: 6-character tracking ID
        **kwargs: Additional fields (run_name, config_file_path, host, instance_id)
    """
    # Extract training config
    training = config_dict.get('training', {})
    reward = config_dict.get('reward', {})
    grouping = config_dict.get('grouping', {})

    with get_connection() as conn:
        conn.execute("""
            INSERT INTO training_runs (
                run_id, wandb_run_id, run_name, config_file_path,
                host, instance_id, chain_of_custody_id,
                created_at, status, config_json,
                batch_size, learning_rate, beta, gradient_method,
                num_gpus, num_objectives, num_scaffolds,
                gradient_accumulation_steps, max_steps, max_grad_norm,
                mixed_precision, gradient_checkpointing, fp16, bf16,
                enable_moving_targets, return_groups, n_clusters
            ) VALUES (
                ?, ?, ?, ?,
                ?, ?, ?,
                ?, 'launched', ?,
                ?, ?, ?, ?,
                ?, ?, ?,
                ?, ?, ?,
                ?, ?, ?, ?,
                ?, ?, ?
            )
        """, (
            run_id,
            wandb_run_id,
            kwargs.get('run_name'),
            kwargs.get('config_file_path'),
            kwargs.get('host'),
            kwargs.get('instance_id'),
            chain_of_custody_id,
            datetime.utcnow().isoformat() + 'Z',
            json.dumps(config_dict),
            # Original 7 fields
            training.get('batch_size'),
            training.get('learning_rate'),
            reward.get('beta'),
            reward.get('gradient_method'),
            training.get('num_processes') or config_dict.get('distributed', {}).get('num_processes'),
            len(config_dict.get('objectives', [])),
            len(config_dict.get('generation', {}).get('scaffolds', [])),
            # New 13 fields
            training.get('gradient_accumulation_steps'),
            training.get('max_steps'),
            training.get('max_grad_norm'),
            training.get('mixed_precision'),
            training.get('gradient_checkpointing'),
            training.get('fp16'),
            training.get('bf16'),
            reward.get('enable_moving_targets'),
            grouping.get('return_groups'),
            grouping.get('n_clusters')
        ))

    print(f"Inserted run {run_id} into database")


def update_run_status(
    run_id: str,
    status: str,
    **kwargs
) -> None:
    """
    Update run status and optional fields.

    Args:
        run_id: Run identifier
        status: New status ('running', 'completed', 'failed', 'crashed')
        **kwargs: Optional fields to update (duration_seconds, final_metrics_json,
                  ended_at, started_at, wandb_run_id, wandb_url, run_name)
    """
    with get_connection() as conn:
        set_clauses = ['status = ?']
        params = [status]

        # Add optional fields
        if 'duration_seconds' in kwargs:
            set_clauses.append('duration_seconds = ?')
            params.append(kwargs['duration_seconds'])

        if 'final_metrics_json' in kwargs:
            set_clauses.append('final_metrics_json = ?')
            params.append(json.dumps(kwargs['final_metrics_json']))

        if 'ended_at' in kwargs:
            set_clauses.append('ended_at = ?')
            params.append(kwargs['ended_at'].isoformat() + 'Z' if hasattr(kwargs['ended_at'], 'isoformat') else kwargs['ended_at'])

        if 'started_at' in kwargs:
            set_clauses.append('started_at = ?')
            params.append(kwargs['started_at'].isoformat() + 'Z' if hasattr(kwargs['started_at'], 'isoformat') else kwargs['started_at'])

        if 'wandb_run_id' in kwargs:
            set_clauses.append('wandb_run_id = ?')
            params.append(kwargs['wandb_run_id'])

        if 'wandb_url' in kwargs:
            set_clauses.append('wandb_url = ?')
            params.append(kwargs['wandb_url'])

        if 'run_name' in kwargs:
            set_clauses.append('run_name = ?')
            params.append(kwargs['run_name'])

        params.append(run_id)  # For WHERE clause

        conn.execute(f"""
            UPDATE training_runs
            SET {', '.join(set_clauses)}
            WHERE run_id = ?
        """, params)

    print(f"Updated run {run_id}: status={status}")


def attach_blog_post(run_id: str, blog_url: str) -> None:
    """Attach blog post URL (called from blog workflow)."""
    with get_connection() as conn:
        conn.execute("""
            UPDATE training_runs
            SET blog_post_url = ?
            WHERE run_id = ?
        """, (blog_url, run_id))

    print(f"Attached blog post to run {run_id}: {blog_url}")


def attach_crash_data(
    run_id: str,
    error_log_s3_key: str,
    crash_report_s3_key: str,
    crash_analysis_s3_key: str
) -> None:
    """Attach crash-related S3 keys (called from crash_notifications.py)."""
    with get_connection() as conn:
        conn.execute("""
            UPDATE training_runs
            SET status = 'crashed',
                ended_at = ?,
                error_log_s3_key = ?,
                crash_report_s3_key = ?,
                crash_analysis_s3_key = ?
            WHERE run_id = ?
        """, (
            datetime.utcnow().isoformat() + 'Z',
            error_log_s3_key,
            crash_report_s3_key,
            crash_analysis_s3_key,
            run_id
        ))

    print(f"Attached crash data to run {run_id}")


def attach_conversation(run_id: str, conversation_s3_key: str) -> None:
    """Attach conversation context (called at launch)."""
    with get_connection() as conn:
        conn.execute("""
            UPDATE training_runs
            SET conversation_s3_key = ?
            WHERE run_id = ?
        """, (conversation_s3_key, run_id))

    print(f"Attached conversation to run {run_id}: {conversation_s3_key}")


def query_runs(
    filters: Optional[Dict[str, Any]] = None,
    order_by: str = 'created_at DESC',
    limit: int = 100
) -> List[Dict[str, Any]]:
    """
    Flexible query interface.

    Args:
        filters: Dict of filter criteria:
            - status: Filter by status
            - host: Filter by host ('expanse' or 'ec2')
            - gradient_method: Filter by gradient method
            - min_duration_hours: Minimum duration in hours
            - created_after: ISO timestamp string
            - has_blog_post: True/False
            - has_crash_analysis: True/False
        order_by: ORDER BY clause (default: 'created_at DESC')
        limit: Maximum results to return

    Returns:
        List of run dictionaries
    """
    with get_connection() as conn:
        where_clauses = []
        params = []

        if filters:
            if 'status' in filters:
                where_clauses.append('status = ?')
                params.append(filters['status'])

            if 'host' in filters:
                where_clauses.append('host = ?')
                params.append(filters['host'])

            if 'gradient_method' in filters:
                where_clauses.append('gradient_method = ?')
                params.append(filters['gradient_method'])

            if 'min_duration_hours' in filters:
                where_clauses.append('duration_seconds >= ?')
                params.append(filters['min_duration_hours'] * 3600)

            if 'created_after' in filters:
                where_clauses.append('created_at >= ?')
                params.append(filters['created_after'])

            if 'has_blog_post' in filters:
                if filters['has_blog_post']:
                    where_clauses.append('blog_post_url IS NOT NULL')
                else:
                    where_clauses.append('blog_post_url IS NULL')

            if 'has_crash_analysis' in filters:
                if filters['has_crash_analysis']:
                    where_clauses.append('crash_analysis_s3_key IS NOT NULL')
                else:
                    where_clauses.append('crash_analysis_s3_key IS NULL')

        where_sql = ' AND '.join(where_clauses) if where_clauses else '1=1'

        query = f"""
            SELECT * FROM training_runs
            WHERE {where_sql}
            ORDER BY {order_by}
            LIMIT ?
        """

        params.append(limit)

        cursor = conn.execute(query, params)

        # Convert to list of dicts
        return [dict(row) for row in cursor.fetchall()]


def get_run(run_id: str) -> Optional[Dict[str, Any]]:
    """Get single run by ID."""
    with get_connection() as conn:
        cursor = conn.execute('SELECT * FROM training_runs WHERE run_id = ?', (run_id,))
        row = cursor.fetchone()
        return dict(row) if row else None


def get_stats() -> Dict[str, Any]:
    """Get database statistics."""
    with get_connection() as conn:
        cursor = conn.execute("""
            SELECT
                COUNT(*) as total_runs,
                COUNT(CASE WHEN status = 'running' THEN 1 END) as running,
                COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
                COUNT(CASE WHEN status = 'crashed' THEN 1 END) as crashed,
                COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed,
                COUNT(CASE WHEN blog_post_url IS NOT NULL THEN 1 END) as with_blog_posts,
                COUNT(CASE WHEN crash_analysis_s3_key IS NOT NULL THEN 1 END) as with_crash_analysis
            FROM training_runs
        """)

        return dict(cursor.fetchone())


if __name__ == '__main__':
    # Initialize database and show stats
    init_db()

    stats = get_stats()
    print("\nDatabase Statistics:")
    print(f"  Total runs: {stats['total_runs']}")
    print(f"  Running: {stats['running']}")
    print(f"  Completed: {stats['completed']}")
    print(f"  Crashed: {stats['crashed']}")
    print(f"  Failed: {stats['failed']}")
    print(f"  With blog posts: {stats['with_blog_posts']}")
    print(f"  With crash analysis: {stats['with_crash_analysis']}")
