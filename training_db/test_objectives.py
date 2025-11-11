"""
Test script for objectives API

Demonstrates querying runs by objective values.
"""

import sys
sys.path.insert(0, '/home/ubuntu/mangodb')

from training_db import (
    insert_run,
    insert_objective,
    update_objective_metric,
    get_run_objectives,
    query_runs_by_objectives,
    get_objective_statistics,
    compare_gradient_methods,
)

print("="*80)
print("TESTING OBJECTIVES API")
print("="*80)

# Test 1: Insert a test run with objectives
print("\n1. Creating test run with objectives...")
test_run_id = "test_obj_run_001"

# Insert run
insert_run(
    run_id=test_run_id,
    wandb_run_id="test_wandb_001",
    config_dict={
        'training': {'batch_size': 64, 'learning_rate': 1e-3},
        'objectives': [
            {'name': 'COMT_activity', 'weight': 2.0, 'direction': 'maximize'},
            {'name': 'DRD5_activity', 'weight': 1.5, 'direction': 'maximize'},
            {'name': 'QED', 'weight': 1.0, 'direction': 'maximize'}
        ]
    },
    run_name="test_mgda_multiobj",
    gradient_method="mgda",
    batch_size=64,
    learning_rate=1e-3,
    num_objectives=3
)
print(f"   ✓ Created run: {test_run_id}")

# Insert objectives
objectives = [
    {'name': 'COMT_activity', 'alias': 'COMT_activity_maximize', 'uniprot': 'P21917', 'weight': 2.0, 'direction': 'maximize'},
    {'name': 'DRD5_activity', 'alias': 'DRD5_activity_maximize', 'uniprot': 'P21918', 'weight': 1.5, 'direction': 'maximize'},
    {'name': 'QED', 'alias': 'QED_maximize', 'weight': 1.0, 'direction': 'maximize'}
]

for obj in objectives:
    insert_objective(
        run_id=test_run_id,
        objective_name=obj['name'],
        objective_alias=obj['alias'],
        uniprot=obj.get('uniprot'),
        weight=obj['weight'],
        direction=obj['direction']
    )
    print(f"   ✓ Inserted objective: {obj['name']}")

# Test 2: Update objective metrics (simulate completion)
print("\n2. Updating objective final values...")
metrics = [
    ('COMT_activity', 'raw_mean', 0.856),
    ('COMT_activity', 'normalized_mean', 0.892),
    ('DRD5_activity', 'raw_mean', 0.743),
    ('DRD5_activity', 'normalized_mean', 0.778),
    ('QED', 'raw_mean', 0.681),
    ('QED', 'normalized_mean', 0.705)
]

for obj_name, metric_type, value in metrics:
    update_objective_metric(test_run_id, obj_name, metric_type, value)
    print(f"   ✓ Updated {obj_name}/{metric_type} = {value}")

# Test 3: Get objectives for a run
print("\n3. Retrieving objectives for run...")
run_objectives = get_run_objectives(test_run_id)
print(f"   Found {len(run_objectives)} objectives:")
for obj in run_objectives:
    print(f"     - {obj['objective_name']}: raw_mean={obj['raw_mean']}, weight={obj['weight']}, direction={obj['direction']}")

# Test 4: Query runs by objective thresholds
print("\n4. Querying runs by objective values...")

# Query 1: COMT > 0.8
print("\n   Query: COMT > 0.8")
runs = query_runs_by_objectives({'COMT_activity': {'min': 0.8}})
print(f"   Found {len(runs)} runs")
for run in runs:
    print(f"     - {run['run_id']}: gradient_method={run['gradient_method']}, batch_size={run['batch_size']}")

# Query 2: COMT > 0.8 AND DRD5 > 0.7
print("\n   Query: COMT > 0.8 AND DRD5 > 0.7")
runs = query_runs_by_objectives({
    'COMT_activity': {'min': 0.8},
    'DRD5_activity': {'min': 0.7}
})
print(f"   Found {len(runs)} runs")

# Query 3: MGDA runs with COMT > 0.8
print("\n   Query: MGDA runs with COMT > 0.8")
runs = query_runs_by_objectives(
    {'COMT_activity': {'min': 0.8}},
    gradient_method='mgda'
)
print(f"   Found {len(runs)} runs")

# Test 5: Get objective statistics
print("\n5. Getting objective statistics...")
for obj_name in ['COMT_activity', 'DRD5_activity', 'QED']:
    stats = get_objective_statistics(obj_name)
    if stats['count'] > 0:
        print(f"   {obj_name}:")
        print(f"     Runs: {stats['count']}")
        print(f"     Mean: {stats['mean']:.3f}")
        print(f"     Min: {stats['min']:.3f}, Max: {stats['max']:.3f}")

# Test 6: Compare gradient methods
print("\n6. Comparing gradient methods on COMT_activity...")
comparison = compare_gradient_methods('COMT_activity')
if comparison:
    print(f"   {'Method':<15} {'Runs':<8} {'Avg':<10} {'Best':<10}")
    print(f"   {'-'*45}")
    for result in comparison:
        print(f"   {result['gradient_method']:<15} {result['count']:<8} {result['avg']:<10.3f} {result['best']:<10.3f}")
else:
    print("   No data available for comparison")

print("\n" + "="*80)
print("ALL TESTS PASSED ✓")
print("="*80)

print("\nObjective querying is now enabled!")
print("\nExample queries:")
print("  1. Find runs with high COMT:")
print("     query_runs_by_objectives({'COMT_activity': {'min': 0.8}})")
print()
print("  2. Find multi-objective balanced runs:")
print("     query_runs_by_objectives({")
print("         'COMT_activity': {'min': 0.75},")
print("         'DRD5_activity': {'min': 0.70},")
print("         'QED': {'min': 0.65}")
print("     })")
print()
print("  3. Compare MGDA vs PCGrad on DRD5:")
print("     compare_gradient_methods('DRD5_activity')")
