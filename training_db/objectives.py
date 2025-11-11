"""
Training Objectives API

Manages per-objective data in the run_objectives table.
Enables queries like "find runs where COMT_activity > 0.8".
"""

import sqlite3
import os
from datetime import datetime
from typing import List, Dict, Optional


def _get_connection():
    """Get database connection"""
    db_path = os.environ.get('TRAINING_DB_PATH', '/home/ubuntu/mango/data/training_runs.db')
    return sqlite3.connect(db_path)


def insert_objective(
    run_id: str,
    objective_name: str,
    objective_alias: Optional[str] = None,
    uniprot: Optional[str] = None,
    weight: Optional[float] = None,
    direction: Optional[str] = None
) -> None:
    """
    Insert objective configuration at launch time

    Args:
        run_id: Run identifier
        objective_name: Objective name (e.g., "DRD5_activity", "COMT_activity")
        objective_alias: Full alias (e.g., "DRD5_activity_maximize")
        uniprot: UniProt ID for protein targets
        weight: Objective weight from config
        direction: 'maximize' or 'minimize'

    Example:
        insert_objective(
            run_id='mgda_test_001',
            objective_name='COMT_activity',
            objective_alias='COMT_activity_maximize',
            uniprot='P21917',
            weight=2.0,
            direction='maximize'
        )
    """
    try:
        conn = _get_connection()
        conn.execute("""
            INSERT INTO run_objectives (
                run_id, objective_name, objective_alias, uniprot,
                weight, direction, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            run_id,
            objective_name,
            objective_alias,
            uniprot,
            weight,
            direction,
            datetime.utcnow()
        ))
        conn.commit()
        conn.close()
    except sqlite3.IntegrityError as e:
        # Objective already exists for this run (duplicate insert)
        pass
    except Exception as e:
        # Silent failure - don't block training
        pass


def update_objective_metric(
    run_id: str,
    objective_name: str,
    metric_type: str,
    value: float
) -> None:
    """
    Update objective final value from W&B summary

    Args:
        run_id: Run identifier
        objective_name: Objective name (must match insert_objective)
        metric_type: One of: 'raw_mean', 'normalized_mean', 'raw_std', 'normalized_std'
        value: Metric value from W&B

    Example:
        # From W&B summary: objectives/COMT_activity_maximize/raw_mean = 0.856
        update_objective_metric(
            run_id='mgda_test_001',
            objective_name='COMT_activity',
            metric_type='raw_mean',
            value=0.856
        )
    """
    column_map = {
        'raw_mean': 'raw_mean',
        'normalized_mean': 'normalized_mean',
        'raw_std': 'raw_std',
        'normalized_std': 'normalized_std'
    }

    if metric_type not in column_map:
        return

    try:
        column = column_map[metric_type]
        conn = _get_connection()
        conn.execute(f"""
            UPDATE run_objectives
            SET {column} = ?, updated_at = ?
            WHERE run_id = ? AND objective_name = ?
        """, (value, datetime.utcnow(), run_id, objective_name))
        conn.commit()
        conn.close()
    except Exception as e:
        # Silent failure
        pass


def get_run_objectives(run_id: str) -> List[Dict]:
    """
    Get all objectives for a run

    Args:
        run_id: Run identifier

    Returns:
        List of objective dicts with all fields

    Example:
        objectives = get_run_objectives('mgda_test_001')
        for obj in objectives:
            print(f"{obj['objective_name']}: {obj['raw_mean']}")
    """
    try:
        conn = _get_connection()
        conn.row_factory = sqlite3.Row
        cursor = conn.execute("""
            SELECT * FROM run_objectives
            WHERE run_id = ?
            ORDER BY objective_name
        """, (run_id,))

        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return results
    except Exception as e:
        return []


def query_runs_by_objectives(
    objective_filters: Dict[str, Dict[str, float]],
    gradient_method: Optional[str] = None,
    status: Optional[str] = None,
    host: Optional[str] = None,
    order_by: str = 'created_at DESC',
    limit: int = 100
) -> List[Dict]:
    """
    Query runs by objective value thresholds

    Args:
        objective_filters: Dict mapping objective_name to constraints
            Example: {
                'COMT_activity': {'min': 0.8, 'max': 1.0},
                'DRD5_activity': {'min': 0.7}
            }
        gradient_method: Filter by gradient method
        status: Filter by status
        host: Filter by host
        order_by: SQL ORDER BY clause
        limit: Max results

    Returns:
        List of run dicts matching ALL objective criteria

    Example:
        # Find MGDA runs with COMT > 0.8 AND DRD5 > 0.7
        runs = query_runs_by_objectives(
            objective_filters={
                'COMT_activity': {'min': 0.8},
                'DRD5_activity': {'min': 0.7}
            },
            gradient_method='mgda',
            status='completed'
        )
    """
    if not objective_filters:
        return []

    try:
        conn = _get_connection()
        conn.row_factory = sqlite3.Row

        # Build query with JOIN for each objective
        joins = []
        where_clauses = []
        params = []

        for i, (obj_name, constraints) in enumerate(objective_filters.items()):
            alias = f"o{i}"
            joins.append(f"""
                JOIN run_objectives {alias} ON r.run_id = {alias}.run_id
                    AND {alias}.objective_name = ?
            """)
            params.append(obj_name)

            # Add min/max constraints
            if 'min' in constraints:
                where_clauses.append(f"{alias}.raw_mean >= ?")
                params.append(constraints['min'])
            if 'max' in constraints:
                where_clauses.append(f"{alias}.raw_mean <= ?")
                params.append(constraints['max'])

        # Add run-level filters
        if gradient_method:
            where_clauses.append("r.gradient_method = ?")
            params.append(gradient_method)
        if status:
            where_clauses.append("r.status = ?")
            params.append(status)
        if host:
            where_clauses.append("r.host = ?")
            params.append(host)

        # Build final query
        where_clause = " AND ".join(where_clauses) if where_clauses else "1=1"
        query = f"""
            SELECT DISTINCT r.*
            FROM training_runs r
            {' '.join(joins)}
            WHERE {where_clause}
            ORDER BY r.{order_by}
            LIMIT ?
        """
        params.append(limit)

        cursor = conn.execute(query, params)
        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return results
    except Exception as e:
        print(f"Error querying by objectives: {e}")
        return []


def get_objective_statistics(
    objective_name: str,
    gradient_method: Optional[str] = None,
    status: str = 'completed'
) -> Dict:
    """
    Get statistics for a specific objective across runs

    Args:
        objective_name: Objective to analyze
        gradient_method: Optionally filter by gradient method
        status: Filter by status (default: 'completed')

    Returns:
        Dict with count, mean, min, max, std for the objective

    Example:
        stats = get_objective_statistics('COMT_activity', gradient_method='mgda')
        print(f"MGDA COMT: avg={stats['mean']:.3f}, best={stats['max']:.3f}")
    """
    try:
        conn = _get_connection()

        where_clauses = ["r.status = ?", "o.objective_name = ?"]
        params = [status, objective_name]

        if gradient_method:
            where_clauses.append("r.gradient_method = ?")
            params.append(gradient_method)

        where_clause = " AND ".join(where_clauses)

        cursor = conn.execute(f"""
            SELECT
                COUNT(*) as count,
                AVG(o.raw_mean) as mean,
                MIN(o.raw_mean) as min,
                MAX(o.raw_mean) as max,
                AVG(o.raw_std) as avg_std
            FROM training_runs r
            JOIN run_objectives o ON r.run_id = o.run_id
            WHERE {where_clause}
        """, params)

        row = cursor.fetchone()
        conn.close()

        return {
            'count': row[0],
            'mean': row[1],
            'min': row[2],
            'max': row[3],
            'avg_std': row[4]
        }
    except Exception as e:
        return {'count': 0, 'mean': None, 'min': None, 'max': None, 'avg_std': None}


def compare_gradient_methods(
    objective_name: str,
    status: str = 'completed'
) -> List[Dict]:
    """
    Compare gradient methods on a specific objective

    Args:
        objective_name: Objective to compare on
        status: Filter by status (default: 'completed')

    Returns:
        List of dicts with gradient_method, count, avg, best

    Example:
        results = compare_gradient_methods('COMT_activity')
        for r in results:
            print(f"{r['gradient_method']}: avg={r['avg']:.3f}, best={r['best']:.3f}")
    """
    try:
        conn = _get_connection()
        cursor = conn.execute("""
            SELECT
                r.gradient_method,
                COUNT(*) as count,
                AVG(o.raw_mean) as avg,
                MAX(o.raw_mean) as best,
                MIN(o.raw_mean) as worst,
                AVG(r.duration_seconds / 3600.0) as avg_hours
            FROM training_runs r
            JOIN run_objectives o ON r.run_id = o.run_id
            WHERE r.status = ?
                AND o.objective_name = ?
                AND r.gradient_method IS NOT NULL
            GROUP BY r.gradient_method
            ORDER BY avg DESC
        """, (status, objective_name))

        results = []
        for row in cursor.fetchall():
            results.append({
                'gradient_method': row[0],
                'count': row[1],
                'avg': row[2],
                'best': row[3],
                'worst': row[4],
                'avg_hours': row[5]
            })

        conn.close()
        return results
    except Exception as e:
        return []


def delete_run_objectives(run_id: str) -> None:
    """
    Delete all objectives for a run (cleanup utility)

    Args:
        run_id: Run identifier
    """
    try:
        conn = _get_connection()
        conn.execute("DELETE FROM run_objectives WHERE run_id = ?", (run_id,))
        conn.commit()
        conn.close()
    except Exception as e:
        pass
