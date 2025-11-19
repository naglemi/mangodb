# Config Mapping Guide

## Purpose

This guide shows exactly how GuacaMol Table 3 objectives map to our training config format. Use this to ensure configs match the paper specifications.

## Table 3 vs Config Format

### GuacaMol Table 3 Format

From the paper (Brown et al. 2019):

```
| Benchmark        | Scoring | Mean | Scoring Function      | Modifier          |
|------------------|---------|------|-----------------------|-------------------|
| Fexofenadine MPO | top-1,  | geom | sim(fexofenadine, AP) | Thresholded(0.8)  |
|                  | top-10, |      | TPSA                  | MaxGaussian(90,2) |
|                  | top-100 |      | logP                  | MinGaussian(4,2)  |
```

### Our Config Format

`configs/05_benchmarks/round5/fexofenadine_mpo_bs96_mgda.yaml`:

```yaml
objectives:
- name: fexofenadine_ap           # Maps to sim(fexofenadine, AP)
  alias: fexofenadine_sim_ap      # Descriptive name
  direction: maximize              # How to optimize
  modifier: thresholded            # Modifier type
  modifier_params:
    threshold: 0.8                 # Modifier parameter
  weight: 1.0

- name: tpsa                       # Maps to TPSA
  alias: tpsa_over_90
  direction: maximize
  modifier: max_gaussian
  modifier_params:
    mu: 90                         # From MaxGaussian(90, 2)
    sigma: 2                       # sigma parameter
  weight: 1.0

- name: logp                       # Maps to logP
  alias: logp_under_4
  direction: minimize              # Note: MinGaussian means "prefer small"
  modifier: min_gaussian
  modifier_params:
    mu: 4                          # From MinGaussian(4, 2)
    sigma: 2                       # sigma parameter
  weight: 1.0
```

## Key Mapping Rules

### 1. Similarity Objectives

**Table 3**: `sim(molecule, fingerprint_type)`

**Config**:
```yaml
name: {molecule}_{fingerprint_lowercase}
alias: {molecule}_sim_{fingerprint_lowercase}
direction: maximize
```

**Examples**:
- `sim(fexofenadine, AP)` → `name: fexofenadine_ap`
- `sim(osimertinib, ECFP4)` → `name: osimertinib_ecfp4`
- `sim(perindopril, ECFP4)` → `name: perindopril_ecfp4`

### 2. Property Objectives

**Table 3**: Property name (TPSA, logP, Bertz, etc.)

**Config**:
```yaml
name: {property_lowercase}
alias: {descriptive_name}
direction: maximize | minimize
```

**Examples**:
- TPSA → `name: tpsa`, `alias: tpsa_over_90`
- logP → `name: logp`, `alias: logp_under_4`

### 3. Count Objectives

**Table 3**: "number of X" or "number X"

**Config**:
```yaml
name: num_{property}
alias: {descriptive_name}
```

**Examples**:
- "number of fluorine atoms" → `name: num_fluorine`
- "number aromatic rings" → `name: num_aromatic_rings`
- "number rings" → `name: num_rings`

### 4. Modifier Mapping

| Table 3 Modifier | Config Modifier | Parameters | Direction |
|-----------------|-----------------|------------|-----------|
| None | `modifier: none` | - | maximize/minimize |
| Gaussian(µ, σ) | `modifier: gaussian` | `{mu: µ, sigma: σ}` | maximize |
| MinGaussian(µ, σ) | `modifier: min_gaussian` | `{mu: µ, sigma: σ}` | **minimize** |
| MaxGaussian(µ, σ) | `modifier: max_gaussian` | `{mu: µ, sigma: σ}` | maximize |
| Thresholded(t) | `modifier: thresholded` | `{threshold: t}` | maximize |

#### Important: Modifier Semantics

**MaxGaussian(µ, σ)**:
- Paper: "Values LARGER than µ get full score"
- Config: `direction: maximize`, `modifier: max_gaussian`
- Example: `MaxGaussian(90, 2)` for TPSA means "prefer TPSA ≥ 90"

**MinGaussian(µ, σ)**:
- Paper: "Values SMALLER than µ get full score"
- Config: `direction: minimize`, `modifier: min_gaussian`
- Example: `MinGaussian(4, 2)` for logP means "prefer logP ≤ 4"

**Gaussian(µ, σ)**:
- Paper: "Target specific value µ"
- Config: `direction: maximize`, `modifier: gaussian`
- Example: `Gaussian(2, 0.5)` targets exact value 2

## Using the Database

### Check Table 3 vs Config Comparison

```bash
python query_benchmarks.py --compare "Fexofenadine MPO"
```

Output:
```
 Objective 1: sim(fexofenadine, AP)
  Table 3:  thresholded(0.8)
  Config:   name=fexofenadine_ap, alias=fexofenadine_sim_ap, direction=maximize
  Modifier: thresholded
  Status:   OK
```

### List All Mismatches

```bash
python query_benchmarks.py --mismatches
```

Shows all 44 objectives with notes about correct implementation.

### Query Specific Mapping

```sql
-- From sqlite3 guacamol_benchmarks.db
SELECT
    table3_function,
    table3_full_spec,
    config_name,
    config_alias,
    config_direction,
    config_notes
FROM table3_vs_config
WHERE benchmark_name = 'Fexofenadine MPO'
ORDER BY objective_order;
```

## Common Issues Found

### Issue 1: Sigma Parameter Mismatches

**Fexofenadine TPSA**:
- ✗ Some configs use `sigma: 10`
- ✓ Table 3 specifies `sigma: 2`

**Fexofenadine logP**:
- ✗ Some configs use `sigma: 1`
- ✓ Table 3 specifies `sigma: 2`

### Issue 2: Thresholded vs Clipped

**Fexofenadine similarity**:
- ✗ Some configs use `modifier: clipped` with `upper_x: 0.8`
- ✓ Table 3 specifies `Thresholded(0.8)`
- Note: Functionally equivalent if `lower_x=0`, but for correctness use `thresholded`

### Issue 3: Direction for MinGaussian

**Osimertinib ECFP6**:
- Table 3: `MinGaussian(0.85, 2)` for similarity
- Interpretation: "Prefer dissimilarity <0.85"
- ✓ Config: `direction: minimize` (penalize high similarity)

## Complete Example: Perindopril MPO

### Table 3

```
| Perindopril MPO | top-1, top-10, top-100 | geom. | sim(perindopril, ECFP4) | None          |
|                 |                        |       | number aromatic rings   | Gaussian(2,0.5)|
```

### Config

```yaml
objectives:
- name: perindopril_ecfp4
  alias: perindopril_sim_ecfp4
  direction: maximize
  modifier: none
  weight: 1.0

- name: num_aromatic_rings
  alias: aromatic_ring_count
  direction: maximize
  modifier: gaussian
  modifier_params:
    mu: 2
    sigma: 0.5
  weight: 1.0

reward:
  gradient_method: "mgda"  # Or imtlg, mean, pcgrad, aligned_mtl

guacamol_benchmark_name: "perindopril_mpo"
```

## Validation Workflow

1. **Check benchmark definition**:
   ```bash
   python query_benchmarks.py --get "Perindopril MPO"
   ```

2. **Compare with config**:
   ```bash
   python query_benchmarks.py --compare "Perindopril MPO"
   ```

3. **Validate config file**:
   ```bash
   python query_benchmarks.py --validate \
     /home/ubuntu/finetune_safe/configs/05_benchmarks/round5/perindopril_mpo_bs96_mgda.yaml \
     "Perindopril MPO"
   ```

4. **Fix any mismatches** based on comparison output

5. **Re-validate** until status is OK

## Database Schema

The `scoring_functions` table now includes:

- `config_name`: Exact "name" field value
- `config_alias`: Exact "alias" field value
- `config_direction`: "maximize" or "minimize"
- `config_notes`: Implementation notes and warnings

View `table3_vs_config` provides side-by-side comparison.

## Reference

All 44 objectives from Table 3 are mapped in the database. Use the database as the authoritative source for config formatting.
