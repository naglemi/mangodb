# GuacaMol Benchmark Database - Implementation Summary

## Mission Accomplished

Successfully created a SQL database that **faithfully reproduces Table 3** from the GuacaMol paper (Brown et al. 2019) as the single source of truth for benchmark definitions.

## Database Stats

- **20 benchmarks** from GuacaMol Table 3
- **44 scoring functions** (objectives) across all benchmarks
- **6 SMARTS abbreviations** (s1-s6 from paper footnote)
- **7 categories**: rediscovery, similarity, isomer, median, mpo, smarts, hop

### Benchmark Breakdown

| Category    | Count | Examples                                    |
|-------------|-------|---------------------------------------------|
| MPO         | 7     | Fexofenadine, Osimertinib, Ranolazine, etc. |
| Rediscovery | 3     | Celecoxib, Troglitazone, Thiothixene        |
| Similarity  | 3     | Aripiprazole, Albuterol, Mestranol          |
| Hop         | 2     | Deco Hop, Scaffold Hop                      |
| Isomer      | 2     | C11H24, C9H10N2O2PF2Cl                      |
| Median      | 2     | Median molecules 1 & 2                      |
| SMARTS      | 1     | Valsartan SMARTS                            |

### Modifier Usage

| Modifier      | Uses | Purpose                            |
|---------------|------|------------------------------------|
| none          | 20   | No transformation                  |
| gaussian      | 9    | Target specific value              |
| thresholded   | 8    | Linear threshold                   |
| max_gaussian  | 4    | Enforce maximum (larger = better)  |
| min_gaussian  | 3    | Enforce minimum (smaller = better) |

## Files Created

### Core Database Files
- `schema.sql` - Database schema with tables, views, indexes
- `populate_table3.sql` - All Table 3 data (20 benchmarks, 44 objectives)
- `guacamol_benchmarks.db` - SQLite database (created by init_db.sh)

### Utilities
- `init_db.sh` - Initialize database from scratch
- `query_benchmarks.py` - Python CLI and library for queries
- `examples.sql` - Example SQL queries

### Documentation
- `README.md` - Comprehensive user guide
- `SUMMARY.md` - This file

## Key Features

### 1. Faithful Table 3 Reproduction

Every benchmark from Table 3 is captured with full fidelity:
- All objectives in correct order
- All modifier types and parameters
- All SMARTS patterns and abbreviations
- Scoring types (top-1, top-10, top-100, etc.)
- Aggregation methods (geometric vs arithmetic)

### 2. Validation Capability

The database can validate training configs against official benchmarks:

```bash
python query_benchmarks.py --validate \
  /path/to/config.yaml \
  "Fexofenadine MPO"
```

Detects mismatches in:
- Number of objectives
- Modifier types
- Modifier parameters (mu, sigma, threshold)
- Aggregation methods

### 3. Query Interface

Multiple ways to query:

**CLI:**
```bash
python query_benchmarks.py --list --category mpo
python query_benchmarks.py --get "Fexofenadine MPO"
python query_benchmarks.py --modifiers
```

**Python API:**
```python
from query_benchmarks import BenchmarkDB

with BenchmarkDB() as db:
    benchmarks = db.get_mpo_benchmarks()
    fex = db.get_benchmark("Fexofenadine MPO")
```

**Direct SQL:**
```bash
sqlite3 guacamol_benchmarks.db
```

## Preventing Future Bugs

### November 19, 2025 Bug Example

**The Bug**: `modifier_max_gaussian` and `modifier_min_gaussian` were implemented backwards.

**Wrong Implementation:**
```python
def modifier_max_gaussian(values, mu, sigma):
    scores = np.ones_like(values)
    above_mask = values > mu  # BACKWARDS!
    scores[above_mask] = np.exp(-0.5 * ((values[above_mask] - mu) / sigma) ** 2)
    return scores
```

**How Database Prevents This:**

```sql
-- Query correct definition from database
SELECT
    'MaxGaussian' as modifier,
    modifier_mu as mu,
    modifier_sigma as sigma,
    'Values LARGER than mu get full score' as definition
FROM scoring_functions
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND function_name = 'TPSA';
```

Returns:
```
modifier     | mu   | sigma | definition
-------------|------|-------|------------------------------------------
MaxGaussian  | 90.0 | 2.0   | Values LARGER than mu get full score
```

Now we have an authoritative reference to validate our implementation.

## Validation Results

Tested validation on existing Fexofenadine config. Found **4 discrepancies**:

1. **Similarity modifier**: Using `clipped` instead of `thresholded`
2. **Similarity threshold**: Missing (should be 0.8)
3. **TPSA sigma**: Using 10 instead of 2.0
4. **logP sigma**: Using 1 instead of 2.0

This demonstrates the database catches real issues!

## Extension Example

Adding a custom benchmark is straightforward:

```sql
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Custom Drug MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Custom drug optimization');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, property_name,
    modifier_type, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Custom Drug MPO'),
     'tpsa', 'TPSA', 'tpsa', 'max_gaussian', 80, 5, 1);
```

## Future Enhancements

Potential additions to the database:

1. **Baseline results table**: Store Graph GA, SMILES LSTM scores from paper
2. **Our training results**: Link W&B runs to benchmarks
3. **Non-GuacaMol benchmarks**: PIDGIN, docking, custom MPOs
4. **Meta-analysis tables**: Track which methods work best for which benchmarks
5. **Config generation**: Auto-generate YAML configs from benchmark definitions

## Location

```
/home/ubuntu/mangodb/benchmark_db/
├── schema.sql              # Database schema
├── populate_table3.sql     # Table 3 data
├── init_db.sh              # Initialization script
├── query_benchmarks.py     # Python query utility
├── examples.sql            # Example queries
├── README.md               # User guide
├── SUMMARY.md              # This file
└── guacamol_benchmarks.db  # SQLite database
```

## References

**Paper**: Brown, N., Fiscato, M., Segler, M. H., & Vaucher, A. C. (2019). GuacaMol: Benchmarking Models for De Novo Molecular Design. *Journal of Chemical Information and Modeling*, 59(3), 1096-1108.

**ArXiv**: https://arxiv.org/abs/1811.09621

**GitHub**: https://github.com/BenevolentAI/guacamol

**Table 3 Source**: `/home/ubuntu/finetune_safe/lit_review/guacamol_paper/guacamol_paper.md` lines 306-352

---

*Database created November 19, 2025 to prevent modifier bugs and maintain benchmark fidelity.*
