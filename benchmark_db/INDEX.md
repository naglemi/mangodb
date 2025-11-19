# GuacaMol Benchmark Database - Quick Reference

## What Is This?

A SQL database containing the exact definitions of all 20 benchmarks from GuacaMol Table 3 (Brown et al. 2019). Created to prevent bugs like the **November 19, 2025 modifier mishap** where `max_gaussian` and `min_gaussian` were implemented backwards.

## Quick Start

```bash
cd /home/ubuntu/mangodb/benchmark_db

# Initialize database
./init_db.sh

# Run demonstration
./demo.sh

# List benchmarks
python query_benchmarks.py --list

# Get specific benchmark
python query_benchmarks.py --get "Fexofenadine MPO"

# Validate a config
python query_benchmarks.py --validate /path/to/config.yaml "Fexofenadine MPO"

# Query with SQL
sqlite3 guacamol_benchmarks.db
```

## File Guide

| File | Purpose | When to Use |
|------|---------|-------------|
| **README.md** | Complete user guide | First time using the database |
| **SUMMARY.md** | Implementation summary | Understanding what was built |
| **INDEX.md** | This file - quick reference | Quick lookup |
| **schema.sql** | Database structure | Understanding table design |
| **populate_table3.sql** | Table 3 data | See all 20 benchmarks |
| **init_db.sh** | Database setup | Creating fresh database |
| **query_benchmarks.py** | Python CLI/API | Querying from Python or CLI |
| **examples.sql** | SQL query examples | Learning SQL queries |
| **demo.sh** | Full demonstration | Seeing everything in action |
| **guacamol_benchmarks.db** | SQLite database | The actual database |

## Common Tasks

### Find Benchmark Definition

```bash
python query_benchmarks.py --get "Fexofenadine MPO"
```

### Validate Config Against Benchmark

```bash
python query_benchmarks.py --validate \
  /home/ubuntu/finetune_safe/configs/05_benchmarks/round5/fexofenadine_mpo_bs96_mgda.yaml \
  "Fexofenadine MPO"
```

### Check Modifier Parameters

```sql
-- From sqlite3 guacamol_benchmarks.db
SELECT
    b.benchmark_name,
    sf.function_name,
    sf.modifier_type,
    sf.modifier_mu,
    sf.modifier_sigma
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.modifier_type = 'max_gaussian';
```

### List All MPO Benchmarks

```bash
python query_benchmarks.py --list --category mpo
```

## Database Contents

- **20 benchmarks** from GuacaMol Table 3
- **44 objectives** across all benchmarks
- **5 modifier types**: none, gaussian, min_gaussian, max_gaussian, thresholded
- **6 SMARTS patterns**: s1-s6 from paper footnote
- **7 categories**: rediscovery, similarity, isomer, median, mpo, smarts, hop

## The Bug This Prevents

**November 19, 2025**: Discovered that `max_gaussian` and `min_gaussian` were backwards.

```python
# WRONG (what we had before database)
def modifier_max_gaussian(values, mu, sigma):
    scores = np.ones_like(values)
    above_mask = values > mu  # BACKWARDS!
    scores[above_mask] = np.exp(...)
```

**Database query reveals correct definition:**

```sql
SELECT modifier_mu, modifier_sigma,
       'Values LARGER than mu get full score' as definition
FROM scoring_functions
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND function_name = 'TPSA';
```

Returns: `mu=90.0, sigma=2.0, definition=Values LARGER than mu get full score`

Now we have an authoritative source to validate implementations.

## Python API Example

```python
from query_benchmarks import BenchmarkDB

with BenchmarkDB() as db:
    # Get all MPO benchmarks
    mpo_benchmarks = db.get_mpo_benchmarks()

    # Get specific benchmark
    fex = db.get_benchmark("Fexofenadine MPO")
    print(f"Objectives: {len(fex['objectives'])}")

    # Validate config
    validation = db.validate_config(
        '/path/to/config.yaml',
        'Fexofenadine MPO'
    )
    if not validation['is_valid']:
        print("Config doesn't match benchmark!")
```

## SQL Query Example

```sql
-- Get complete Fexofenadine definition
SELECT * FROM benchmark_objectives
WHERE benchmark_name = 'Fexofenadine MPO'
ORDER BY objective_order;
```

## Reference

**Paper**: Brown et al. (2019) "GuacaMol: Benchmarking Models for De Novo Molecular Design"

**Location**: `/home/ubuntu/mangodb/benchmark_db/`

**Created**: November 19, 2025

**Purpose**: Single source of truth for benchmark definitions

---

For detailed documentation, see **README.md**
For implementation details, see **SUMMARY.md**
For examples, run `./demo.sh`
