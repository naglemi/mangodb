

# GuacaMol Benchmark Database

A SQL database that faithfully reproduces Table 3 from the GuacaMol paper (Brown et al. 2019) and serves as the single source of truth for benchmark definitions.

## Purpose

This database was created to avoid issues like the **November 19, 2025 GuacaMol modifier bug** where `max_gaussian` and `min_gaussian` were implemented backwards because we didn't have a clear reference. This database ensures:

1. **Single source of truth**: All benchmark definitions in one place
2. **Exact paper reproduction**: Table 3 faithfully reproduced with all objectives and modifiers
3. **Validation**: Compare our training configs against official definitions
4. **Extensibility**: Easy to add new benchmarks beyond GuacaMol

## Database Structure

### Tables

**benchmarks**: Top-level benchmark definitions
- `benchmark_name`: Official name from paper
- `scoring_type`: 'top-1', 'top-10', 'top-100', etc.
- `aggregation_method`: 'geometric', 'arithmetic', or NULL
- `category`: 'rediscovery', 'similarity', 'mpo', 'isomer', 'median', 'smarts', 'hop'

**scoring_functions**: Individual objectives within each benchmark
- `function_type`: 'similarity', 'tpsa', 'logp', 'isomer', 'smarts', 'count', 'bertz', 'qed'
- `target_molecule`: Target for similarity functions
- `fingerprint_type`: 'ECFP4', 'ECFP6', 'FCFP4', 'AP', 'PHCO'
- `modifier_type`: 'none', 'gaussian', 'min_gaussian', 'max_gaussian', 'thresholded'
- `modifier_mu`, `modifier_sigma`, `modifier_threshold`: Modifier parameters

**smarts_abbreviations**: Lookup table for SMARTS patterns (s1-s6 from paper)

**baseline_results**: Performance of baseline models (for future population)

### Views

**benchmark_objectives**: Complete benchmark definitions with all objectives joined

**benchmark_summary**: High-level overview with objective counts

## Contents

The database contains all 20 benchmarks from GuacaMol Table 3:

### Rediscovery (3 benchmarks)
- Celecoxib rediscovery
- Troglitazone rediscovery
- Thiothixene rediscovery

### Similarity (3 benchmarks)
- Aripiprazole similarity
- Albuterol similarity
- Mestranol similarity

### Isomer (2 benchmarks)
- C11H24 (159 isomers)
- C9H10N2O2PF2Cl (250 isomers)

### Median Molecules (2 benchmarks)
- Median molecules 1 (camphor-menthol)
- Median molecules 2 (tadalafil-sildenafil)

### MPO - Multi-Property Optimization (7 benchmarks)
- Osimertinib MPO (4 objectives)
- Fexofenadine MPO (3 objectives)
- Ranolazine MPO (4 objectives)
- Perindopril MPO (2 objectives)
- Amlodipine MPO (2 objectives)
- Sitagliptin MPO (4 objectives)
- Zaleplon MPO (2 objectives)

### SMARTS (1 benchmark)
- Valsartan SMARTS (4 objectives)

### Hop Tasks (2 benchmarks)
- Deco Hop (4 objectives)
- Scaffold Hop (3 objectives)

## Usage

### Initialize Database

```bash
cd /home/ubuntu/mangodb/benchmark_db
./init_db.sh
```

### Query from Command Line

```bash
# List all benchmarks
python query_benchmarks.py --list

# List only MPO benchmarks
python query_benchmarks.py --list --category mpo

# Get detailed info on specific benchmark
python query_benchmarks.py --get "Fexofenadine MPO"

# Show modifier usage statistics
python query_benchmarks.py --modifiers

# Export benchmark as JSON config template
python query_benchmarks.py --export "Fexofenadine MPO" --output fexofenadine_template.json

# Validate a training config against benchmark definition
python query_benchmarks.py --validate \
  /home/ubuntu/finetune_safe/configs/05_benchmarks/round5/fexofenadine_mpo_bs96_mgda.yaml \
  "Fexofenadine MPO"
```

### Query from Python

```python
from query_benchmarks import BenchmarkDB

with BenchmarkDB() as db:
    # Get all MPO benchmarks
    mpo_benchmarks = db.get_mpo_benchmarks()

    # Get specific benchmark with all objectives
    fex = db.get_benchmark("Fexofenadine MPO")
    print(f"Fexofenadine has {len(fex['objectives'])} objectives")

    # Find all benchmarks using TPSA
    tpsa_benchmarks = db.search_by_objective('tpsa')

    # Validate our config
    validation = db.validate_config(
        '/home/ubuntu/finetune_safe/configs/05_benchmarks/round5/fexofenadine_mpo_bs96_mgda.yaml',
        'Fexofenadine MPO'
    )
    if not validation['is_valid']:
        print("Config does not match benchmark!")
        print(validation['objective_mismatches'])
```

### Query with SQL

```bash
sqlite3 /home/ubuntu/mangodb/benchmark_db/guacamol_benchmarks.db
```

```sql
-- Get all benchmarks using max_gaussian modifier
SELECT DISTINCT b.benchmark_name, sf.function_name, sf.modifier_mu, sf.modifier_sigma
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.modifier_type = 'max_gaussian'
ORDER BY b.benchmark_name;

-- Get Fexofenadine complete definition
SELECT * FROM benchmark_objectives
WHERE benchmark_name = 'Fexofenadine MPO'
ORDER BY objective_order;

-- Count objectives by type
SELECT function_type, COUNT(*) as count
FROM scoring_functions
GROUP BY function_type
ORDER BY count DESC;
```

## November 19 Bug Example

**The Bug**: Our `modifier_max_gaussian` and `modifier_min_gaussian` were backwards:

```python
# WRONG (what we had)
def modifier_max_gaussian(values, mu, sigma):
    scores = np.ones_like(values)
    above_mask = values > mu  # BACKWARDS!
    scores[above_mask] = np.exp(-0.5 * ((values[above_mask] - mu) / sigma) ** 2)
    return scores
```

**How the database prevents this**:

```sql
-- Query the database for correct definition
SELECT function_name, modifier_type, modifier_mu, modifier_sigma
FROM scoring_functions
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND function_name = 'TPSA';
```

Returns:
```
function_name | modifier_type | modifier_mu | modifier_sigma
TPSA          | max_gaussian  | 90          | 2
```

Check paper definition:
- **MaxGaussian(µ, σ)**: "Values LARGER than µ get full score, values smaller than µ decrease"

Now we have an authoritative source to verify our implementation against.

## Baseline Results

The database includes baseline scores for all 20 goal-directed benchmarks from **GuacaMol Table 2** (Brown et al. 2019). This allows direct comparison of our results with published state-of-the-art methods.

### Available Baseline Models

1. **Best from Dataset** - Virtual screening baseline (upper bound for simple database search)
2. **SMILES LSTM** - Neural network model using SMILES representation
3. **SMILES GA** - Genetic algorithm with SMILES strings
4. **Graph GA** - Genetic algorithm with graph representation (best optimizer)
5. **Graph MCTS** - Monte Carlo Tree Search with graph representation

### Query Baseline Results

**Get all baselines for a specific benchmark:**
```sql
SELECT br.model_name, br.score
FROM baseline_results br
JOIN benchmarks b ON br.benchmark_id = b.benchmark_id
WHERE b.benchmark_name = 'Fexofenadine MPO'
ORDER BY br.score DESC;
```

Returns:
```
model_name          | score
Graph GA            | 0.998
SMILES LSTM         | 0.959
SMILES GA           | 0.931
Best from Dataset   | 0.817
Graph MCTS          | 0.695
```

**Compare all benchmarks side-by-side:**
```sql
SELECT * FROM baseline_comparison
WHERE category = 'mpo'
ORDER BY best_dataset DESC;
```

**Find benchmarks where Graph GA achieved perfect score:**
```sql
SELECT b.benchmark_name, br.score
FROM benchmarks b
JOIN baseline_results br ON b.benchmark_id = br.benchmark_id
WHERE br.model_name = 'Graph GA' AND br.score = 1.000;
```

### Benchmarking Your Results

When you have results from your own training runs, compare against these baselines:

```python
# Example: Your model achieved 0.965 on Fexofenadine MPO
your_score = 0.965

# Query baselines
cursor.execute("""
    SELECT model_name, score
    FROM baseline_results br
    JOIN benchmarks b ON br.benchmark_id = b.benchmark_id
    WHERE b.benchmark_name = 'Fexofenadine MPO'
    ORDER BY score DESC
""")

for model, score in cursor.fetchall():
    if your_score > score:
        print(f"✓ Beat {model}: {your_score:.3f} > {score:.3f}")
    else:
        print(f"✗ Below {model}: {your_score:.3f} < {score:.3f}")
```

Output:
```
✓ Beat SMILES GA: 0.965 > 0.931
✓ Beat Best from Dataset: 0.965 > 0.817
✓ Beat Graph MCTS: 0.965 > 0.695
✗ Below Graph GA: 0.965 < 0.998
✗ Below SMILES LSTM: 0.965 < 0.959
```

### State-of-the-Art Scores

**Graph GA** is the best optimizer overall (total score: 17.983):
- Perfect scores (1.000) on 9 benchmarks: all rediscovery, all similarity, Deco Hop, Scaffold Hop
- Strong MPO performance: 0.953 (Osimertinib), 0.998 (Fexofenadine), 0.920 (Ranolazine)
- Challenging benchmarks: 0.406 (Median molecules 1), 0.891 (Sitagliptin)

**SMILES LSTM** (total score: 17.340):
- Perfect scores on 6 benchmarks (all rediscovery + all similarity)
- Best compound quality (77% pass filters, same as Best from Dataset)
- Good optimization + learned molecular distribution

**Target scores for strong performance:**
- **Must beat**: Best from Dataset (virtual screening baseline)
- **Competitive**: SMILES GA or SMILES LSTM
- **State-of-the-art**: Match or exceed Graph GA

## Extending the Database

### Adding New Benchmarks

```sql
-- Add a custom benchmark
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('My Custom MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Custom multi-objective benchmark');

-- Add objectives
INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, property_name,
    modifier_type, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'My Custom MPO'),
     'tpsa', 'TPSA', 'tpsa', 'max_gaussian', 80, 5, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'My Custom MPO'),
     'logp', 'logP', 'logp', 'gaussian', 3.0, 0.5, 2);
```

### Adding Baseline Results

```sql
-- Add baseline performance data
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'),
     'Graph GA', 0.524, 'From GuacaMol paper Table 4'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'),
     'SMILES LSTM', 0.931, 'From GuacaMol paper Table 4');
```

## Files

- `schema.sql`: Database schema definition
- `populate_table3.sql`: All Table 3 benchmark data
- `populate_baseline_results.sql`: Baseline scores from GuacaMol Table 2
- `add_config_mappings.sql`: Config name/alias/direction mappings
- `populate_config_mappings.sql`: Complete config mapping data
- `init_db.sh`: Initialize database script
- `query_benchmarks.py`: Python query utility
- `guacamol_benchmarks.db`: SQLite database (created by init_db.sh)
- `README.md`: This file

## Reference

**Paper**: Brown, N., Fiscato, M., Segler, M. H., & Vaucher, A. C. (2019). GuacaMol: Benchmarking Models for De Novo Molecular Design. *Journal of Chemical Information and Modeling*, 59(3), 1096-1108.

**ArXiv**: https://arxiv.org/abs/1811.09621

**Code**: https://github.com/BenevolentAI/guacamol

**Table 3 Location**: `/home/ubuntu/finetune_safe/lit_review/guacamol_paper/guacamol_paper.md` lines 306-352
