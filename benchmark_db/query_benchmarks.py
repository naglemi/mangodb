#!/usr/bin/env python3
"""
Query utility for GuacaMol Benchmark Database.

Provides convenient functions to retrieve benchmark definitions
and compare with our training configs.
"""

import sqlite3
from pathlib import Path
from typing import List, Dict, Any, Optional
import json


class BenchmarkDB:
    """Interface to GuacaMol benchmark database."""

    def __init__(self, db_path: str = None):
        if db_path is None:
            db_path = Path(__file__).parent / "guacamol_benchmarks.db"
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row  # Return rows as dicts

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.conn.close()

    def list_benchmarks(self, category: str = None) -> List[Dict[str, Any]]:
        """List all benchmarks, optionally filtered by category."""
        query = "SELECT * FROM benchmark_summary"
        params = []

        if category:
            query += " WHERE category = ?"
            params.append(category)

        query += " ORDER BY category, benchmark_name"

        cursor = self.conn.cursor()
        cursor.execute(query, params)
        return [dict(row) for row in cursor.fetchall()]

    def get_benchmark(self, benchmark_name: str) -> Optional[Dict[str, Any]]:
        """Get complete benchmark definition with all objectives."""
        # Get benchmark metadata
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT * FROM benchmarks WHERE benchmark_name = ?",
            (benchmark_name,)
        )
        benchmark = cursor.fetchone()

        if not benchmark:
            return None

        benchmark = dict(benchmark)

        # Get all objectives
        cursor.execute(
            """
            SELECT * FROM scoring_functions
            WHERE benchmark_id = ?
            ORDER BY objective_order
            """,
            (benchmark['benchmark_id'],)
        )
        benchmark['objectives'] = [dict(row) for row in cursor.fetchall()]

        return benchmark

    def get_mpo_benchmarks(self) -> List[Dict[str, Any]]:
        """Get all MPO (multi-property optimization) benchmarks."""
        return self.list_benchmarks(category='mpo')

    def search_by_objective(self, objective_type: str) -> List[Dict[str, Any]]:
        """Find benchmarks that use a specific objective type."""
        cursor = self.conn.cursor()
        cursor.execute(
            """
            SELECT DISTINCT b.*
            FROM benchmarks b
            JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
            WHERE sf.function_type = ?
            ORDER BY b.benchmark_name
            """,
            (objective_type,)
        )
        return [dict(row) for row in cursor.fetchall()]

    def get_modifier_usage(self) -> Dict[str, int]:
        """Get counts of modifier usage across all benchmarks."""
        cursor = self.conn.cursor()
        cursor.execute(
            """
            SELECT modifier_type, COUNT(*) as count
            FROM scoring_functions
            GROUP BY modifier_type
            ORDER BY count DESC
            """
        )
        return {row['modifier_type']: row['count'] for row in cursor.fetchall()}

    def get_config_comparison(self, benchmark_name: str) -> List[Dict[str, Any]]:
        """Get Table 3 vs config comparison for a benchmark."""
        cursor = self.conn.cursor()
        cursor.execute(
            """
            SELECT * FROM table3_vs_config
            WHERE benchmark_name = ?
            ORDER BY objective_order
            """,
            (benchmark_name,)
        )
        return [dict(row) for row in cursor.fetchall()]

    def list_config_mismatches(self) -> List[Dict[str, Any]]:
        """List all objectives with config notes (potential mismatches)."""
        cursor = self.conn.cursor()
        cursor.execute(
            """
            SELECT
                benchmark_name,
                objective_order,
                table3_function,
                config_name,
                config_notes
            FROM table3_vs_config
            WHERE config_notes IS NOT NULL
            ORDER BY benchmark_name, objective_order
            """
        )
        return [dict(row) for row in cursor.fetchall()]

    def export_benchmark_json(self, benchmark_name: str, output_path: str = None) -> Dict[str, Any]:
        """Export benchmark definition as JSON (compatible with our config format)."""
        benchmark = self.get_benchmark(benchmark_name)

        if not benchmark:
            raise ValueError(f"Benchmark '{benchmark_name}' not found")

        # Convert to our config format
        config = {
            'experiment_tracking': {
                'what_is_new': f"GuacaMol {benchmark['benchmark_name']} benchmark",
                'hypothesis': benchmark['description'],
                'tags': ['guacamol', 'benchmark', benchmark['category']]
            },
            'objectives': []
        }

        for obj in benchmark['objectives']:
            objective = {
                'name': obj['property_name'] or obj['function_type'],
                'alias': obj['function_name'].replace('(', '_').replace(')', '').replace(', ', '_'),
                'direction': 'maximize',  # Default, needs manual adjustment
                'weight': 1.0
            }

            # Add modifier if present
            if obj['modifier_type'] and obj['modifier_type'] != 'none':
                objective['modifier'] = obj['modifier_type']
                objective['modifier_params'] = {}

                if obj['modifier_mu'] is not None:
                    objective['modifier_params']['mu'] = obj['modifier_mu']
                if obj['modifier_sigma'] is not None:
                    objective['modifier_params']['sigma'] = obj['modifier_sigma']
                if obj['modifier_threshold'] is not None:
                    objective['modifier_params']['threshold'] = obj['modifier_threshold']

            config['objectives'].append(objective)

        # Add aggregation method
        if benchmark['aggregation_method']:
            config['reward'] = {
                'gradient_method': benchmark['aggregation_method']  # Note: This is scoring aggregation, not gradient
            }

        config['guacamol_benchmark_name'] = benchmark['benchmark_name']

        if output_path:
            with open(output_path, 'w') as f:
                json.dump(config, f, indent=2)

        return config

    def validate_config(self, config_path: str, benchmark_name: str) -> Dict[str, Any]:
        """Compare a training config against the benchmark definition."""
        import yaml

        # Load config
        with open(config_path) as f:
            config = yaml.safe_load(f)

        # Get benchmark
        benchmark = self.get_benchmark(benchmark_name)

        if not benchmark:
            raise ValueError(f"Benchmark '{benchmark_name}' not found")

        # Compare objectives
        validation = {
            'benchmark_name': benchmark_name,
            'config_path': config_path,
            'num_objectives_expected': len(benchmark['objectives']),
            'num_objectives_actual': len(config.get('objectives', [])),
            'aggregation_expected': benchmark['aggregation_method'],
            'aggregation_actual': config.get('reward', {}).get('gradient_method'),
            'objective_mismatches': []
        }

        # Check each objective
        for i, expected_obj in enumerate(benchmark['objectives']):
            if i >= len(config.get('objectives', [])):
                validation['objective_mismatches'].append({
                    'index': i,
                    'error': 'Missing objective',
                    'expected': expected_obj['function_name']
                })
                continue

            actual_obj = config['objectives'][i]

            # Check modifier
            if expected_obj['modifier_type'] != 'none':
                if actual_obj.get('modifier') != expected_obj['modifier_type']:
                    validation['objective_mismatches'].append({
                        'index': i,
                        'field': 'modifier',
                        'expected': expected_obj['modifier_type'],
                        'actual': actual_obj.get('modifier')
                    })

                # Check modifier parameters
                expected_params = {}
                if expected_obj['modifier_mu'] is not None:
                    expected_params['mu'] = expected_obj['modifier_mu']
                if expected_obj['modifier_sigma'] is not None:
                    expected_params['sigma'] = expected_obj['modifier_sigma']
                if expected_obj['modifier_threshold'] is not None:
                    expected_params['threshold'] = expected_obj['modifier_threshold']

                actual_params = actual_obj.get('modifier_params', {})

                for param, expected_val in expected_params.items():
                    actual_val = actual_params.get(param)
                    if actual_val != expected_val:
                        validation['objective_mismatches'].append({
                            'index': i,
                            'field': f'modifier_params.{param}',
                            'expected': expected_val,
                            'actual': actual_val
                        })

        validation['is_valid'] = len(validation['objective_mismatches']) == 0

        return validation


def main():
    """CLI interface for database queries."""
    import argparse

    parser = argparse.ArgumentParser(description='Query GuacaMol Benchmark Database')
    parser.add_argument('--list', action='store_true', help='List all benchmarks')
    parser.add_argument('--category', type=str, help='Filter by category')
    parser.add_argument('--get', type=str, help='Get specific benchmark')
    parser.add_argument('--export', type=str, help='Export benchmark as JSON config')
    parser.add_argument('--output', type=str, help='Output path for export')
    parser.add_argument('--validate', type=str, nargs=2, metavar=('CONFIG', 'BENCHMARK'),
                        help='Validate config against benchmark')
    parser.add_argument('--modifiers', action='store_true', help='Show modifier usage stats')
    parser.add_argument('--compare', type=str, help='Show Table 3 vs config comparison for benchmark')
    parser.add_argument('--mismatches', action='store_true', help='List all config mismatches/notes')

    args = parser.parse_args()

    with BenchmarkDB() as db:
        if args.list:
            benchmarks = db.list_benchmarks(category=args.category)
            print(f"\nFound {len(benchmarks)} benchmarks:\n")
            for b in benchmarks:
                print(f"  {b['benchmark_name']:<30} ({b['category']:<12}) {b['num_objectives']} objectives")

        elif args.get:
            benchmark = db.get_benchmark(args.get)
            if benchmark:
                print(f"\n{benchmark['benchmark_name']}")
                print(f"Category: {benchmark['category']}")
                print(f"Scoring: {benchmark['scoring_type']}")
                print(f"Aggregation: {benchmark['aggregation_method']}")
                print(f"\nObjectives:")
                for obj in benchmark['objectives']:
                    print(f"  {obj['objective_order']}. {obj['function_name']}")
                    print(f"     Modifier: {obj['modifier_type']}", end='')
                    if obj['modifier_mu'] is not None:
                        print(f" (μ={obj['modifier_mu']}, σ={obj['modifier_sigma']})", end='')
                    if obj['modifier_threshold'] is not None:
                        print(f" (threshold={obj['modifier_threshold']})", end='')
                    print()
            else:
                print(f"Benchmark '{args.get}' not found")

        elif args.export:
            config = db.export_benchmark_json(args.export, args.output)
            if args.output:
                print(f"Exported to {args.output}")
            else:
                print(json.dumps(config, indent=2))

        elif args.validate:
            config_path, benchmark_name = args.validate
            validation = db.validate_config(config_path, benchmark_name)
            print(f"\nValidation Results:")
            print(f"Config: {config_path}")
            print(f"Benchmark: {benchmark_name}")
            print(f"Valid: {'✓' if validation['is_valid'] else '✗'}")
            print(f"\nObjectives: {validation['num_objectives_actual']}/{validation['num_objectives_expected']}")
            print(f"Aggregation: {validation['aggregation_actual']} (expected: {validation['aggregation_expected']})")

            if validation['objective_mismatches']:
                print(f"\nMismatches ({len(validation['objective_mismatches'])}):")
                for mismatch in validation['objective_mismatches']:
                    print(f"  Objective {mismatch.get('index', '?')}: {mismatch}")

        elif args.modifiers:
            stats = db.get_modifier_usage()
            print("\nModifier Usage:")
            for modifier, count in stats.items():
                print(f"  {modifier:<20} {count:>3} uses")

        elif args.compare:
            comparison = db.get_config_comparison(args.compare)
            if not comparison:
                print(f"Benchmark '{args.compare}' not found")
            else:
                print(f"\nTable 3 vs Config Comparison: {args.compare}")
                print("=" * 100)
                for obj in comparison:
                    print(f"\n Objective {obj['objective_order']}: {obj['table3_function']}")
                    print(f"  Table 3:  {obj['table3_full_spec']}")
                    print(f"  Config:   name={obj['config_name']}, alias={obj['config_alias']}, direction={obj['config_direction']}")
                    print(f"  Modifier: {obj['config_modifier']}")
                    if obj['config_notes']:
                        print(f"  ⚠ NOTES:  {obj['config_notes']}")
                    print(f"  Status:   {obj['status']}")

        elif args.mismatches:
            mismatches = db.list_config_mismatches()
            print(f"\nConfig Mismatches/Notes ({len(mismatches)} total):")
            print("=" * 100)
            for m in mismatches:
                print(f"\n{m['benchmark_name']} - Objective {m['objective_order']}")
                print(f"  Table 3: {m['table3_function']}")
                print(f"  Config:  {m['config_name']}")
                print(f"  Notes:   {m['config_notes']}")


if __name__ == '__main__':
    main()
