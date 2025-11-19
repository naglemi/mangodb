#!/bin/bash
# Demonstration of GuacaMol Benchmark Database

echo "========================================================================"
echo "GuacaMol Benchmark Database - Complete Demonstration"
echo "========================================================================"
echo ""

DB_PATH="/home/ubuntu/mangodb/benchmark_db/guacamol_benchmarks.db"

# Section 1: Database Overview
echo "1. DATABASE OVERVIEW"
echo "--------------------"
echo ""
echo "Total benchmarks:"
sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM benchmarks;"
echo ""
echo "Total objectives:"
sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM scoring_functions;"
echo ""
echo "Benchmarks by category:"
sqlite3 "$DB_PATH" -box "SELECT category, COUNT(*) as count FROM benchmarks GROUP BY category ORDER BY count DESC;"
echo ""

# Section 2: Fexofenadine Example (the bug that motivated this database)
echo "2. FEXOFENADINE MPO BENCHMARK (November 19 Bug Example)"
echo "--------------------------------------------------------"
echo ""
echo "Complete benchmark definition:"
sqlite3 "$DB_PATH" -box "SELECT * FROM benchmark_objectives WHERE benchmark_name = 'Fexofenadine MPO' ORDER BY objective_order;"
echo ""
echo "MaxGaussian definition for TPSA:"
sqlite3 "$DB_PATH" -box "
SELECT
    'TPSA' as property,
    'MaxGaussian' as modifier,
    modifier_mu as mu,
    modifier_sigma as sigma,
    'Values LARGER than mu get full score' as correct_definition
FROM scoring_functions
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND function_name = 'TPSA';
"
echo ""
echo "MinGaussian definition for logP:"
sqlite3 "$DB_PATH" -box "
SELECT
    'logP' as property,
    'MinGaussian' as modifier,
    modifier_mu as mu,
    modifier_sigma as sigma,
    'Values SMALLER than mu get full score' as correct_definition
FROM scoring_functions
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND function_name = 'logP';
"
echo ""

# Section 3: Modifier Analysis
echo "3. MODIFIER USAGE ACROSS ALL BENCHMARKS"
echo "----------------------------------------"
echo ""
sqlite3 "$DB_PATH" -box "SELECT modifier_type, COUNT(*) as uses FROM scoring_functions GROUP BY modifier_type ORDER BY uses DESC;"
echo ""
echo "All MaxGaussian usage:"
sqlite3 "$DB_PATH" -box "
SELECT b.benchmark_name, sf.function_name, sf.modifier_mu as mu, sf.modifier_sigma as sigma
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.modifier_type = 'max_gaussian'
ORDER BY b.benchmark_name, sf.objective_order;
"
echo ""

# Section 4: Python API Demo
echo "4. PYTHON API DEMONSTRATION"
echo "---------------------------"
echo ""
python3 << 'PYTHON'
from query_benchmarks import BenchmarkDB

with BenchmarkDB() as db:
    # Get MPO benchmarks
    mpo = db.get_mpo_benchmarks()
    print(f"Found {len(mpo)} MPO benchmarks:")
    for b in mpo:
        print(f"  - {b['benchmark_name']}: {b['num_objectives']} objectives")
    
    print()
    
    # Get Fexofenadine details
    fex = db.get_benchmark("Fexofenadine MPO")
    print(f"Fexofenadine MPO details:")
    print(f"  Category: {fex['category']}")
    print(f"  Aggregation: {fex['aggregation_method']}")
    print(f"  Objectives:")
    for obj in fex['objectives']:
        print(f"    {obj['objective_order']}. {obj['function_name']}: {obj['modifier_type']}", end='')
        if obj['modifier_mu'] is not None:
            print(f" (μ={obj['modifier_mu']}, σ={obj['modifier_sigma']})", end='')
        print()
PYTHON
echo ""

# Section 5: Validation Example
echo "5. CONFIG VALIDATION EXAMPLE"
echo "----------------------------"
echo ""
echo "Validating fexofenadine_mpo_bs96_mgda.yaml against database..."
python3 query_benchmarks.py --validate \
  /home/ubuntu/finetune_safe/configs/05_benchmarks/round5/fexofenadine_mpo_bs96_mgda.yaml \
  "Fexofenadine MPO" | head -20
echo ""

echo "========================================================================"
echo "Demonstration complete!"
echo "========================================================================"
echo ""
echo "Try these commands:"
echo "  python query_benchmarks.py --list"
echo "  python query_benchmarks.py --get 'Osimertinib MPO'"
echo "  python query_benchmarks.py --modifiers"
echo "  sqlite3 $DB_PATH"
echo ""
