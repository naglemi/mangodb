# Agent Transfer Document: GuacaMol Benchmark Database

**Created**: 2025-11-19
**Location**: `/home/ubuntu/mangodb/benchmark_db/`
**Purpose**: Single source of truth for GuacaMol benchmark definitions and baseline results

---

## Executive Summary

This database faithfully reproduces **GuacaMol Table 3** (Brown et al. 2019) and contains baseline performance scores from **GuacaMol Table 2**. It serves as the authoritative reference for:

1. **Benchmark definitions**: All 20 goal-directed benchmarks with exact specifications
2. **Baseline results**: Published scores from 5 state-of-the-art models
3. **Config validation**: Mapping between Table 3 specs and our YAML config format
4. **Implementation details**: Count-based fingerprints, isomer scoring with total atom count penalty

Created to prevent bugs like the **November 19, 2025 modifier bug** where `max_gaussian` and `min_gaussian` were implemented backwards because we lacked an authoritative reference.

---

## Database Location and Files

**Database file**: `/home/ubuntu/mangodb/benchmark_db/guacamol_benchmarks.db`

**Key files**:
```
/home/ubuntu/mangodb/benchmark_db/
├── guacamol_benchmarks.db           # SQLite database (76 KB)
├── schema.sql                       # Database schema definition
├── populate_table3.sql              # All 20 benchmarks from GuacaMol Table 3
├── populate_baseline_results.sql    # Baseline scores from GuacaMol Table 2
├── add_config_mappings.sql          # Schema additions for config mapping
├── populate_config_mappings.sql     # Config name/alias/direction mappings
├── query_benchmarks.py              # Python query utility (15 KB)
├── init_db.sh                       # Database initialization script
├── README.md                        # Complete documentation (7.8 KB)
├── CONFIG_MAPPING_GUIDE.md          # How Table 3 maps to YAML configs
├── baseline_results.csv             # Exported baseline comparison
└── [other documentation files]
```

---

## Database Schema

### Core Tables

#### `benchmarks`
Top-level benchmark definitions (20 rows):
```sql
CREATE TABLE benchmarks (
    benchmark_id INTEGER PRIMARY KEY AUTOINCREMENT,
    benchmark_name TEXT NOT NULL UNIQUE,              -- 'Fexofenadine MPO', 'Celecoxib rediscovery', etc.
    scoring_type TEXT NOT NULL,                       -- 'top-1', 'top-10', 'top-100', 'top-159', 'top-250'
    aggregation_method TEXT,                          -- 'geometric', 'arithmetic', NULL for single-objective
    category TEXT,                                    -- 'rediscovery', 'similarity', 'mpo', 'isomer', 'median', 'smarts', 'hop'
    description TEXT,
    paper_reference TEXT DEFAULT 'Brown et al. 2019 GuacaMol'
);
```

**Categories**:
- `rediscovery` (3): Celecoxib, Troglitazone, Thiothixene
- `similarity` (3): Aripiprazole, Albuterol, Mestranol
- `isomer` (2): C11H24 (159 isomers), C9H10N2O2PF2Cl (250 isomers)
- `median` (2): Median molecules 1 (camphor-menthol), Median molecules 2 (tadalafil-sildenafil)
- `mpo` (7): Osimertinib, Fexofenadine, Ranolazine, Perindopril, Amlodipine, Sitagliptin, Zaleplon
- `smarts` (1): Valsartan SMARTS
- `hop` (2): Deco Hop, Scaffold Hop

#### `scoring_functions`
Individual objectives within each benchmark (44 total objectives):
```sql
CREATE TABLE scoring_functions (
    scoring_function_id INTEGER PRIMARY KEY AUTOINCREMENT,
    benchmark_id INTEGER NOT NULL,                    -- Foreign key to benchmarks
    function_type TEXT NOT NULL,                      -- 'similarity', 'tpsa', 'logp', 'isomer', 'smarts', 'count', 'bertz', 'qed'
    function_name TEXT NOT NULL,                      -- 'sim(fexofenadine, AP)', 'TPSA', 'logP', etc.

    -- Function-specific fields
    target_molecule TEXT,                             -- For similarity functions
    fingerprint_type TEXT,                            -- 'ECFP4', 'ECFP6', 'FCFP4', 'AP', 'PHCO'
    property_name TEXT,                               -- 'tpsa', 'logp', 'num_aromatic_rings', etc.
    smarts_pattern TEXT,                              -- SMARTS pattern string
    smarts_present BOOLEAN,                           -- TRUE=pattern required, FALSE=pattern forbidden
    isomer_formula TEXT,                              -- Molecular formula (e.g., 'C16H15F6N5O')

    -- Modifier parameters
    modifier_type TEXT,                               -- 'none', 'gaussian', 'min_gaussian', 'max_gaussian', 'thresholded'
    modifier_mu REAL,                                 -- μ parameter for Gaussian modifiers
    modifier_sigma REAL,                              -- σ parameter for Gaussian modifiers
    modifier_threshold REAL,                          -- threshold parameter for Thresholded modifier

    objective_order INTEGER NOT NULL,                 -- Order within benchmark (1, 2, 3, ...)

    -- Config mapping (added later)
    config_name TEXT,                                 -- YAML 'name' field (e.g., 'fexofenadine_ap')
    config_alias TEXT,                                -- YAML 'alias' field (e.g., 'fexofenadine_sim_ap')
    config_direction TEXT,                            -- 'maximize' or 'minimize'
    config_notes TEXT,                                -- Implementation notes

    FOREIGN KEY (benchmark_id) REFERENCES benchmarks(benchmark_id) ON DELETE CASCADE
);
```

#### `baseline_results`
Published baseline scores from GuacaMol Table 2 (100 rows = 20 benchmarks × 5 models):
```sql
CREATE TABLE baseline_results (
    result_id INTEGER PRIMARY KEY AUTOINCREMENT,
    benchmark_id INTEGER NOT NULL,
    model_name TEXT NOT NULL,                         -- 'Graph GA', 'SMILES LSTM', 'SMILES GA', 'Graph MCTS', 'Best from Dataset'
    score REAL,                                       -- Final benchmark score (0.0 to 1.0)
    notes TEXT,                                       -- Source reference

    FOREIGN KEY (benchmark_id) REFERENCES benchmarks(benchmark_id) ON DELETE CASCADE,
    UNIQUE(benchmark_id, model_name)
);
```

#### `smarts_abbreviations`
SMARTS pattern lookup table:
```sql
CREATE TABLE smarts_abbreviations (
    abbreviation TEXT PRIMARY KEY,                    -- 's1', 's2', 's3', 's4', 's5', 's6'
    full_smarts TEXT NOT NULL,                        -- Full SMARTS pattern string
    description TEXT                                  -- Human-readable description
);
```

### Views

#### `benchmark_objectives`
Complete benchmark definitions with all objectives joined:
```sql
CREATE VIEW benchmark_objectives AS
SELECT
    b.benchmark_name,
    b.scoring_type,
    b.aggregation_method,
    b.category,
    sf.objective_order,
    sf.function_name as table3_function_name,
    sf.function_type,
    sf.target_molecule,
    sf.fingerprint_type,
    sf.property_name,
    sf.smarts_pattern,
    sf.smarts_present,
    sf.isomer_formula,
    sf.modifier_type as table3_modifier,
    sf.modifier_mu,
    sf.modifier_sigma,
    sf.modifier_threshold,
    sf.config_name,
    sf.config_alias,
    sf.config_direction,
    sf.config_notes
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
ORDER BY b.benchmark_name, sf.objective_order;
```

#### `benchmark_summary`
High-level overview with objective counts:
```sql
CREATE VIEW benchmark_summary AS
SELECT
    b.benchmark_name,
    b.category,
    b.scoring_type,
    b.aggregation_method,
    COUNT(sf.scoring_function_id) as num_objectives,
    GROUP_CONCAT(sf.function_name, ' | ') as objectives_list
FROM benchmarks b
LEFT JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
GROUP BY b.benchmark_id
ORDER BY b.category, b.benchmark_name;
```

#### `table3_vs_config`
Side-by-side comparison of Table 3 specs vs config representation:
```sql
CREATE VIEW table3_vs_config AS
SELECT
    b.benchmark_name,
    sf.objective_order,
    sf.function_name as table3_function,
    sf.modifier_type as table3_modifier,
    CASE
        WHEN sf.modifier_mu IS NOT NULL THEN
            sf.modifier_type || '(' || sf.modifier_mu || ', ' || sf.modifier_sigma || ')'
        WHEN sf.modifier_threshold IS NOT NULL THEN
            sf.modifier_type || '(' || sf.modifier_threshold || ')'
        ELSE
            COALESCE(sf.modifier_type, 'none')
    END as table3_full_spec,
    sf.config_name,
    sf.config_alias,
    sf.config_direction,
    sf.modifier_type as config_modifier,
    CASE
        WHEN sf.config_name IS NULL THEN 'NOT MAPPED'
        WHEN sf.config_notes IS NOT NULL THEN 'HAS NOTES'
        ELSE 'OK'
    END as status,
    sf.config_notes
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
ORDER BY b.benchmark_name, sf.objective_order;
```

#### `baseline_comparison`
Side-by-side comparison of all baseline model scores:
```sql
CREATE VIEW baseline_comparison AS
SELECT
    b.benchmark_name,
    b.category,
    MAX(CASE WHEN br.model_name = 'Best from Dataset' THEN br.score END) as best_dataset,
    MAX(CASE WHEN br.model_name = 'SMILES LSTM' THEN br.score END) as smiles_lstm,
    MAX(CASE WHEN br.model_name = 'SMILES GA' THEN br.score END) as smiles_ga,
    MAX(CASE WHEN br.model_name = 'Graph GA' THEN br.score END) as graph_ga,
    MAX(CASE WHEN br.model_name = 'Graph MCTS' THEN br.score END) as graph_mcts
FROM benchmarks b
LEFT JOIN baseline_results br ON b.benchmark_id = br.benchmark_id
GROUP BY b.benchmark_name, b.category
ORDER BY b.category, b.benchmark_name;
```

---

## Baseline Results Summary

### Model Rankings (by total score across 20 benchmarks)

1. **Graph GA**: 17.983 (best optimizer)
   - Perfect scores (1.000) on 9 benchmarks
   - All rediscovery (3), all similarity (3), Deco Hop, Scaffold Hop, nearly perfect on isomers
   - Strong MPO: Fexofenadine (0.998), Osimertinib (0.953), Ranolazine (0.920)
   - Weakness: Generates molecules with poor quality (only 40% pass filters)

2. **SMILES LSTM**: 17.340 (best neural model)
   - Perfect scores on 6 benchmarks (all rediscovery + all similarity)
   - Best compound quality: 77% pass filters (same as Best from Dataset)
   - Good optimization + learned molecular distribution
   - Strong MPO: Fexofenadine (0.959), Osimertinib (0.907), Amlodipine (0.894)

3. **SMILES GA**: 14.396
   - Consistently decent performance
   - Compound quality: 36% pass filters

4. **Best from Dataset**: 12.144 (virtual screening baseline)
   - This is the minimum score any good model should beat
   - Represents pure database search without optimization

5. **Graph MCTS**: 9.009 (worst)
   - Poor performance overall
   - Only 22% pass quality filters

### Key Baseline Scores to Beat

**For Fexofenadine MPO** (most commonly tested in our experiments):
- Graph GA: **0.998** (state-of-the-art)
- SMILES LSTM: 0.959
- SMILES GA: 0.931
- Best from Dataset: 0.817 (minimum to beat)
- Graph MCTS: 0.695

**For Osimertinib MPO**:
- Graph GA: **0.953** (state-of-the-art)
- SMILES LSTM: 0.907
- SMILES GA: 0.886
- Best from Dataset: 0.839
- Graph MCTS: 0.784

**For Perindopril MPO**:
- SMILES LSTM: **0.808** (state-of-the-art)
- Graph GA: 0.792
- SMILES GA: 0.661
- Best from Dataset: 0.575
- Graph MCTS: 0.385

**Challenging benchmarks** (all models struggle):
- Median molecules 1: Best is 0.438 (SMILES LSTM)
- Median molecules 2: Best is 0.432 (Graph GA)
- Sitagliptin MPO: Best is 0.891 (Graph GA)

---

## Implementation Details Discovered

### 1. Count-Based Fingerprints (Critical Finding - November 19, 2025)

**Problem**: GuacaMol uses **count-based fingerprints** (track feature frequencies), but our initial implementation used **bit vector fingerprints** (binary presence/absence). This caused similarity score mismatches up to 0.04.

**Solution**: Changed all fingerprint types in `objectives.py`:
- `ECFP4` → `ECFP4c` (count-based)
- `ECFP6` → `ECFP6c` (count-based)
- `FCFP4` → `FCFP4c` (count-based)
- `AP` and `PHCO` already count-based (no change needed)

**How to identify**:
- Count-based: `ECFP4c`, `ECFP6c`, `FCFP4c` (note the 'c' suffix)
- Bit vector: `ECFP4`, `ECFP6`, `FCFP4` (no 'c')

**MolScore support**: MolScore's `Fingerprints.get()` supports count-based with 'c' suffix:
```python
# Count-based (correct for GuacaMol)
fp = Fingerprints.get(mol, "ECFP4c", nBits=2048, asarray=False)

# Bit vector (wrong for GuacaMol)
fp = Fingerprints.get(mol, "ECFP4", nBits=2048, asarray=False)
```

**Validation**: All tests in `benchmark_function_tests/03_test_similarity_scoring.py` pass with exact match (diff < 1e-6) after switching to count-based.

### 2. Isomer Scoring with Total Atom Count (Critical Finding - November 19, 2025)

**Problem**: Our `calculate_formula_match_score()` was missing the **total atom count penalty** that GuacaMol uses.

**GuacaMol implementation** (from `guacamol/common_scoring_functions.py`):
```python
def determine_scoring_functions(molecular_formula: str):
    functions = []

    # Score for each element (sigma=1.0)
    for element, n_atoms in element_occurrences:
        functions.append(RdkitScoringFunction(
            descriptor=AtomCounter(element),
            score_modifier=GaussianModifier(mu=n_atoms, sigma=1.0)
        ))

    # CRITICAL: Score for TOTAL number of atoms (sigma=2.0)
    functions.append(RdkitScoringFunction(
        descriptor=num_atoms,
        score_modifier=GaussianModifier(mu=total_number_atoms, sigma=2.0)
    ))

    return functions
```

**Our fix** (added to `objectives.py` lines 84-89):
```python
# Score total atom count (sigma=2.0) - CRITICAL FOR GUACAMOL MATCH
target_total_atoms = sum(target_elements.values())
mol_total_atoms = sum(mol_elements.values())
total_diff = mol_total_atoms - target_total_atoms
total_score = np.exp(-0.5 * (total_diff / 2.0) ** 2)
element_scores.append(total_score)
```

**Validation**: All tests in `benchmark_function_tests/01_test_isomer_scoring.py` pass with exact match after adding total atom count.

### 3. Modifier Semantics (From November 19 Modifier Bug)

**CRITICAL DISTINCTION**:

**MaxGaussian(µ, σ)** - "Values LARGER than µ get full score"
```python
def modifier_max_gaussian(values, mu, sigma):
    scores = np.ones_like(values)
    below_mask = values < mu  # Values BELOW mu are penalized
    scores[below_mask] = np.exp(-0.5 * ((values[below_mask] - mu) / sigma) ** 2)
    return scores
```
- Example: `MaxGaussian(90, 2)` for TPSA means "prefer TPSA ≥ 90"
- Full score for TPSA=100, partial score for TPSA=85

**MinGaussian(µ, σ)** - "Values SMALLER than µ get full score"
```python
def modifier_min_gaussian(values, mu, sigma):
    scores = np.ones_like(values)
    above_mask = values > mu  # Values ABOVE mu are penalized
    scores[above_mask] = np.exp(-0.5 * ((values[above_mask] - mu) / sigma) ** 2)
    return scores
```
- Example: `MinGaussian(4, 2)` for logP means "prefer logP ≤ 4"
- Full score for logP=2, partial score for logP=6

**Gaussian(µ, σ)** - "Target specific value µ"
```python
def modifier_gaussian(values, mu, sigma):
    return np.exp(-0.5 * ((values - mu) / sigma) ** 2)
```
- Example: `Gaussian(2, 0.5)` means "prefer exactly 2"
- Peak score at value=2, symmetric decay on both sides

**Thresholded(t)** - "Full score above threshold"
```python
def modifier_thresholded(values, threshold):
    return np.where(values >= threshold, 1.0, values / threshold)
```
- Example: `Thresholded(0.8)` for similarity
- Full score for similarity ≥ 0.8, linear ramp below

### 4. Config Name Mapping Rules

**Table 3 to YAML config mapping**:

| Table 3 | Config Name | Config Alias | Config Direction |
|---------|-------------|--------------|------------------|
| `sim(fexofenadine, AP)` | `fexofenadine_ap` | `fexofenadine_sim_ap` | `maximize` |
| `TPSA` with `MaxGaussian(90,2)` | `tpsa` | `tpsa_over_90` | `maximize` |
| `logP` with `MinGaussian(4,2)` | `logp` | `logp_under_4` | `minimize` |
| `number of fluorine atoms` | `num_fluorine` | `fluorine_count` | varies |
| `number aromatic rings` | `num_aromatic_rings` | `aromatic_ring_count` | varies |

**Rules**:
1. Similarity: `{molecule}_{fingerprint_lowercase}` (e.g., `osimertinib_ecfp4`)
2. Properties: `{property_lowercase}` (e.g., `tpsa`, `logp`)
3. Counts: `num_{property}` (e.g., `num_fluorine`, `num_aromatic_rings`)
4. Direction: `maximize` for MaxGaussian/Thresholded, `minimize` for MinGaussian, `maximize` for plain Gaussian

---

## Config Validation Findings (November 19, 2025)

Created validation script `/tmp/validate_all_configs.py` and documented results in `/home/ubuntu/finetune_safe/november_19_fexofenadine_analysis.md`.

**Results**:
- **6 configs OK** (no issues)
- **18 configs with issues** across 5 severity levels

### Severity 1: SWAPPED OBJECTIVES
**Ranolazine MPO** (configs/05_benchmarks/round5/ranolazine_mpo_bs96_*.yaml):
- Objectives 3 and 4 are in WRONG ORDER
- Config has: 1) similarity, 2) logP, 3) fluorine_count, 4) TPSA
- Table 3: 1) similarity, 2) logP, 3) TPSA, 4) fluorine_count
- **Impact**: Geometric mean calculated with wrong objective order

### Severity 2: WRONG TABLE 3 SPECS
**Valsartan SMARTS** (all configs):
- Objectives don't match Table 3 at all
- Need to verify against GuacaMol paper

**Deco Hop** (all method_imtlg templates):
- All objectives appear wrong
- Need complete rewrite based on Table 3

**Scaffold Hop** (all method_imtlg templates):
- All objectives appear wrong
- Need complete rewrite based on Table 3

### Severity 3: WRONG PARAMETERS
**Fexofenadine MPO**:
- TPSA: Config has `sigma: 10`, Table 3 has `sigma: 2`
- logP: Config has `sigma: 1`, Table 3 has `sigma: 2`

**Osimertinib MPO**:
- ECFP6 similarity: Config has `sigma: 0.1`, Table 3 has `sigma: 2`
- TPSA: Config has `sigma: 10`, Table 3 has `sigma: 2`
- logP: Config has `sigma: 1`, Table 3 has `sigma: 2`

**Sitagliptin MPO**:
- Similarity: Config has `mu: 1.49`, Table 3 has `mu: 2.0165`
- TPSA: Config has `mu: 121.26`, Table 3 has `mu: 77.04`

### Severity 4: WRONG DIRECTIONS
**Method IMTLG templates** (all 12 configs in method_imtlg/):
- Many have `direction: minimize` when should be `maximize`
- Many have `direction: maximize` when should be `minimize`
- Need systematic review of all directions

### Severity 5: WRONG MODIFIERS
**Round 5 configs**:
- Some use `clipped` when Table 3 specifies `thresholded`
- Functionally similar but should match Table 3 for correctness

**Method IMTLG templates**:
- Some have typo: `modifier: "threshold"` instead of `"thresholded"`

---

## Test Suite Created

Location: `/home/ubuntu/finetune_safe/benchmark_function_tests/`

### Test Scripts

1. **`01_test_isomer_scoring.py`** - Tests isomer scoring against GuacaMol's `IsomerScoringFunction`
   - Tests: C16H15F6N5O (Sitagliptin), C19H17N3O2 (Zaleplon), C2H6O, C3H7NO2
   - Status: ✓ ALL PASS (max diff < 1e-6)

2. **`02_test_smarts_scoring.py`** - Tests SMARTS pattern matching against GuacaMol's `SMARTSScoringFunction`
   - Tests: methylsulfonyl, thiazole, pyrimidine, tetrazole, benzene, halogens
   - Includes both present (true) and absent (false) patterns
   - Status: ✓ ALL PASS

3. **`03_test_similarity_scoring.py`** - Tests count-based fingerprint similarity
   - Tests: ECFP4c, ECFP6c, FCFP4c, AP fingerprints
   - Validates MolScore vs GuacaMol fingerprint methods match
   - Status: ✓ ALL PASS (max diff < 1e-6)

4. **`04_test_descriptor_scoring.py`** - Tests GuacaMol modifiers with TPSA and logP
   - Tests: MaxGaussian, MinGaussian, Gaussian modifiers
   - Validates our modifier implementations match GuacaMol exactly
   - Status: ✓ ALL PASS (max diff < 1e-6)

5. **`00_run_all_tests.sh`** - Master test runner
   ```bash
   #!/bin/bash
   source ~/miniconda3/etc/profile.d/conda.sh
   conda activate fresh

   ALL_PASSED=true

   python3 01_test_isomer_scoring.py || ALL_PASSED=false
   python3 02_test_smarts_scoring.py || ALL_PASSED=false
   python3 03_test_similarity_scoring.py || ALL_PASSED=false
   python3 04_test_descriptor_scoring.py || ALL_PASSED=false

   if [ "$ALL_PASSED" = true ]; then
       echo "✓✓✓ ALL BENCHMARK FUNCTION TESTS PASSED ✓✓✓"
       exit 0
   else
       echo "✗✗✗ SOME TESTS FAILED ✗✗✗"
       exit 1
   fi
   ```

### Test Results (as of November 19, 2025)

```
✓✓✓ ALL BENCHMARK FUNCTION TESTS PASSED ✓✓✓
Our implementations exactly match GuacaMol's official scoring functions
Safe to use for benchmark training and comparison
```

**Key findings**:
- Isomer scoring: 100% match after adding total atom count penalty
- SMARTS scoring: 100% match (was already correct)
- Similarity: 100% match after switching to count-based fingerprints
- Descriptors: 100% match (modifiers were correct after November 19 fix)

---

## Usage Examples

### Initialize/Rebuild Database

```bash
cd /home/ubuntu/mangodb/benchmark_db
./init_db.sh
```

This runs:
1. `schema.sql` - Creates tables and views
2. `populate_table3.sql` - Adds all 20 benchmarks with 44 objectives
3. `populate_baseline_results.sql` - Adds 100 baseline scores
4. `add_config_mappings.sql` - Adds config mapping columns
5. `populate_config_mappings.sql` - Populates config mappings

### Query Specific Benchmark

```bash
sqlite3 /home/ubuntu/mangodb/benchmark_db/guacamol_benchmarks.db
```

```sql
-- Get complete Fexofenadine MPO definition
SELECT * FROM benchmark_objectives
WHERE benchmark_name = 'Fexofenadine MPO'
ORDER BY objective_order;

-- Get baseline scores for Fexofenadine MPO
SELECT model_name, score
FROM baseline_results br
JOIN benchmarks b ON br.benchmark_id = b.benchmark_id
WHERE b.benchmark_name = 'Fexofenadine MPO'
ORDER BY score DESC;
```

### Compare All Benchmarks

```sql
-- Side-by-side comparison of all baseline models
SELECT * FROM baseline_comparison
WHERE category = 'mpo'
ORDER BY graph_ga DESC;

-- Find benchmarks where Graph GA achieved perfect score
SELECT b.benchmark_name, br.score
FROM benchmarks b
JOIN baseline_results br ON b.benchmark_id = br.benchmark_id
WHERE br.model_name = 'Graph GA' AND br.score = 1.000;
```

### Validate Config Against Database

```python
import sqlite3

DB_PATH = "/home/ubuntu/mangodb/benchmark_db/guacamol_benchmarks.db"

def get_benchmark_from_db(benchmark_name: str):
    """Get benchmark definition from database."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM benchmarks WHERE benchmark_name = ?", (benchmark_name,))
    benchmark = dict(cursor.fetchone())

    cursor.execute("""
        SELECT * FROM scoring_functions
        WHERE benchmark_id = ?
        ORDER BY objective_order
    """, (benchmark['benchmark_id'],))

    benchmark['objectives'] = [dict(row) for row in cursor.fetchall()]
    conn.close()

    return benchmark

# Example: Get Fexofenadine MPO
fex = get_benchmark_from_db('Fexofenadine MPO')
print(f"Fexofenadine has {len(fex['objectives'])} objectives")
for obj in fex['objectives']:
    print(f"  {obj['objective_order']}. {obj['function_name']}: {obj['modifier_type']}")
```

### Export Baseline Comparison CSV

```bash
cd /home/ubuntu/mangodb/benchmark_db
sqlite3 -header -csv guacamol_benchmarks.db \
    "SELECT * FROM baseline_comparison;" > baseline_results.csv
```

Result: `baseline_results.csv` with columns:
- `benchmark_name`
- `category`
- `best_dataset`
- `smiles_lstm`
- `smiles_ga`
- `graph_ga`
- `graph_mcts`

---

## Outstanding Tasks

### Immediate (High Priority)

1. **Fix Ranolazine configs** - SEVERITY 1
   - Swap objectives 3 and 4 in all Ranolazine configs
   - Current: logP, TPSA, fluorine, WRONG
   - Correct: logP, fluorine, TPSA (from Table 3)

2. **Fix parameter mismatches** - SEVERITY 3
   - Fexofenadine: Change TPSA sigma 10→2, logP sigma 1→2
   - Osimertinib: Change ECFP6 sigma 0.1→2, TPSA sigma 10→2, logP sigma 1→2
   - Sitagliptin: Change similarity mu, TPSA mu to Table 3 values

3. **Review method_imtlg templates** - SEVERITY 4
   - Check all 12 configs in `configs/05_benchmarks/method_imtlg/`
   - Fix direction (maximize vs minimize) mismatches
   - Fix modifier typos ("threshold" → "thresholded")

### Medium Priority

4. **Verify Valsartan/Deco Hop/Scaffold Hop** - SEVERITY 2
   - These benchmarks may have completely wrong objectives
   - Need to carefully read GuacaMol paper Table 3 and rewrite from scratch
   - Check SMARTS abbreviations (s1-s6) in database

5. **Add missing benchmarks to database**
   - Median molecules 1 and 2 are in Table 3 but validation script couldn't find them
   - Verify they exist in `populate_table3.sql`

### Low Priority (Future Enhancements)

6. **Add more baseline results from literature**
   - User mentioned "maybe another one or two" papers with additional baselines
   - EvoMol scores mentioned in configs (`# SOTA to beat: 0.955 (EvoMol)`)
   - Search literature for recent GuacaMol benchmark papers

7. **Document implementation notes in database**
   - Add `IMPLEMENTATION_NOTES.md` documenting:
     - Count-based vs bit vector fingerprints
     - Isomer scoring with total atom count
     - Any other implementation details not explicit in Table 3

8. **Add constraints/validation to schema**
   - Add CHECK constraint ensuring modifier parameters are consistent
   - Add triggers to validate config_direction matches modifier_type semantics

---

## Common Queries Cheatsheet

```sql
-- List all MPO benchmarks
SELECT benchmark_name, num_objectives
FROM benchmark_summary
WHERE category = 'mpo';

-- Get objectives for a specific benchmark
SELECT objective_order, function_name, modifier_type, modifier_mu, modifier_sigma
FROM benchmark_objectives
WHERE benchmark_name = 'Fexofenadine MPO'
ORDER BY objective_order;

-- Find all benchmarks using TPSA
SELECT DISTINCT benchmark_name
FROM scoring_functions
WHERE property_name = 'tpsa';

-- Get baseline comparison for MPO benchmarks
SELECT * FROM baseline_comparison
WHERE category = 'mpo'
ORDER BY graph_ga DESC;

-- Find hardest benchmarks (lowest Graph GA score)
SELECT b.benchmark_name, br.score
FROM benchmarks b
JOIN baseline_results br ON b.benchmark_id = br.benchmark_id
WHERE br.model_name = 'Graph GA'
ORDER BY br.score ASC
LIMIT 10;

-- Export Table 3 vs Config comparison
SELECT * FROM table3_vs_config
WHERE status != 'OK';
```

---

## Important Notes for Future Agents

### 1. Database is NOT Modified by Config Changes

The database represents **GuacaMol Table 3 as published**. It does NOT change when we modify our training configs. Think of it as a "spec sheet" - our configs should match the database, not the other way around.

### 2. Fingerprint Type Confusion

- **In database**: `fingerprint_type = 'ECFP4'` (no 'c' suffix, matches Table 3)
- **In objectives.py**: `"fp": "ECFP4c"` ('c' suffix for count-based implementation)
- **In configs**: `name: osimertinib_ecfp4` (no 'c', just an identifier)

The 'c' suffix is an **implementation detail** in objectives.py, not part of the config or database naming.

### 3. November 19 Modifier Bug Context

The bug that prompted this database creation:
- `max_gaussian` and `min_gaussian` were implemented **backwards**
- MaxGaussian should give full score for values LARGER than µ (was penalizing them)
- MinGaussian should give full score for values SMALLER than µ (was penalizing them)
- Bug affected Fexofenadine training results significantly
- Fixed in objectives.py, validated with test suite

### 4. Config Validation Script Location

The validation script is at `/tmp/validate_all_configs.py` (temporary location). It should probably be moved to `~/mangodb/benchmark_db/` for permanent storage.

### 5. Test Suite Must Pass Before Benchmark Training

Before running any new benchmark training:
```bash
cd /home/ubuntu/finetune_safe/benchmark_function_tests
./00_run_all_tests.sh
```

If tests fail, DO NOT proceed with training - scoring functions don't match GuacaMol.

### 6. User Instructions About Config Edits

User explicitly said during validation: **"don't edit any of the configs yet"**

The 18 configs with issues are documented, but user wants to review before making changes. Do not automatically fix configs without explicit user approval.

---

## References

**GuacaMol Paper**:
- Brown, N., Fiscato, M., Segler, M. H., & Vaucher, A. C. (2019).
- GuacaMol: Benchmarking Models for De Novo Molecular Design.
- *Journal of Chemical Information and Modeling*, 59(3), 1096-1108.
- ArXiv: https://arxiv.org/abs/1811.09621
- Code: https://github.com/BenevolentAI/guacamol

**Local Paper Location**:
- `/home/ubuntu/finetune_safe/lit_review/guacamol_paper/guacamol_paper.md`
- Table 3: Lines 306-352 (benchmark definitions)
- Table 2: Lines 178-201 (baseline results)

**Key Finding Papers Referenced**:
- Isomer scoring: GuacaMol code `/home/ubuntu/guacamol/guacamol/common_scoring_functions.py`
- Fingerprints: MolScore utilities `/home/ubuntu/.local/lib/python3.10/site-packages/molscore/scoring_functions/utils.py`

---

## Contact/History

**Created by**: Agent session November 19, 2025
**Purpose**: Knowledge transfer for future agents
**Last Updated**: 2025-11-19
**Status**: Database populated and validated, config fixes pending user approval

**Key Contributors**:
- User: Identified November 19 modifier bug, requested systematic validation
- Agent: Created database, populated baselines, validated implementations, created test suite

**Next Agent Should**:
1. Read this document completely
2. Query database to understand benchmark structure
3. Run test suite to verify implementations still match GuacaMol
4. Wait for user approval before fixing configs
5. Continue adding baseline results from additional papers user provides
