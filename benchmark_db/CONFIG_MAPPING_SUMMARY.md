# Config Mapping Extension - Summary

## What Was Added

Extended the GuacaMol benchmark database to include exact config mappings showing how each Table 3 objective should be represented in our training configs.

## New Database Columns

Added to `scoring_functions` table:

| Column | Type | Purpose |
|--------|------|---------|
| `config_name` | TEXT | Exact "name" field value in YAML |
| `config_alias` | TEXT | Exact "alias" field value in YAML |
| `config_direction` | TEXT | "maximize" or "minimize" |
| `config_notes` | TEXT | Implementation notes/warnings |

## New Views

**`table3_vs_config`**: Side-by-side comparison of Table 3 vs config representation

```sql
SELECT * FROM table3_vs_config WHERE benchmark_name = 'Fexofenadine MPO';
```

Returns:
- Table 3 function name and full spec
- Config name, alias, direction
- Status (OK, HAS NOTES, NOT MAPPED)
- Config notes

## New CLI Commands

### Compare Table 3 vs Config

```bash
python query_benchmarks.py --compare "Fexofenadine MPO"
```

Shows exact mapping for each objective with any notes.

### List All Mismatches

```bash
python query_benchmarks.py --mismatches
```

Shows all 43 objectives that have implementation notes.

## Coverage

- **20 benchmarks** from GuacaMol Table 3
- **44 objectives** all mapped to config format
- **43 objectives** have implementation notes (98%)
- **0 unmapped** - every objective has config representation

## Key Findings

### Parameter Mismatches Found

1. **Fexofenadine TPSA**: Some configs use sigma=10, should be sigma=2
2. **Fexofenadine logP**: Some configs use sigma=1, should be sigma=2
3. **Fexofenadine similarity**: Using clipped instead of thresholded modifier

### Direction Clarifications

- **MinGaussian**: Always use `direction: minimize` (prefer small values)
- **MaxGaussian**: Always use `direction: maximize` (prefer large values)
- **Gaussian**: Always use `direction: maximize` (target exact value)

### Special Cases Documented

- **Sitagliptin similarity**: Inverted objective (maximize dissimilarity)
- **Osimertinib ECFP6**: MinGaussian for similarity means "not too similar"
- **Isomer objectives**: Special top-N scoring (top-159, top-250)
- **SMARTS objectives**: Require custom implementation

## Example Usage

### Get Correct Config Format

```bash
# Show how Fexofenadine should be configured
python query_benchmarks.py --compare "Fexofenadine MPO"
```

Output:
```
 Objective 2: TPSA
  Table 3:  max_gaussian(90.0, 2.0)
  Config:   name=tpsa, alias=tpsa_over_90, direction=maximize
  Modifier: max_gaussian
  ⚠ NOTES:  Table 3 specifies sigma=2 but some configs use sigma=10 (incorrect)
```

### Validate Existing Config

```bash
python query_benchmarks.py --validate \
  configs/05_benchmarks/round5/fexofenadine_mpo_bs96_mgda.yaml \
  "Fexofenadine MPO"
```

Catches:
- Wrong sigma values
- Wrong modifier types
- Missing objectives
- Wrong aggregation method

### Query from Python

```python
from query_benchmarks import BenchmarkDB

with BenchmarkDB() as db:
    # Get config comparison
    comparison = db.get_config_comparison("Fexofenadine MPO")

    for obj in comparison:
        print(f"{obj['table3_function']} → {obj['config_name']}")
        if obj['config_notes']:
            print(f"  Warning: {obj['config_notes']}")

    # List all mismatches
    mismatches = db.list_config_mismatches()
    print(f"Found {len(mismatches)} objectives with notes")
```

### SQL Query

```sql
-- Get all objectives with wrong sigma parameters
SELECT
    benchmark_name,
    table3_function,
    config_name,
    config_notes
FROM table3_vs_config
WHERE config_notes LIKE '%sigma%incorrect%'
ORDER BY benchmark_name;
```

## Files Created/Modified

### New Files
- `CONFIG_MAPPING_GUIDE.md` - Complete guide with examples
- `CONFIG_MAPPING_SUMMARY.md` - This file
- `add_config_mappings.sql` - Schema extension
- `populate_config_mappings.sql` - Config data for all 44 objectives

### Modified Files
- `query_benchmarks.py` - Added --compare and --mismatches commands
- `guacamol_benchmarks.db` - Extended with config mappings

### Updated Views
- `benchmark_objectives` - Now includes config columns
- `table3_vs_config` - New view for comparison

## Impact

### Before
- No authoritative source for config format
- Manual comparison with Table 3 required
- Easy to make mistakes with sigma values
- Unclear how to represent objectives

### After
- Database has exact config representation for every objective
- One command shows correct format: `--compare`
- All mismatches documented with notes
- Validation catches wrong parameters automatically

## Next Steps

1. **Fix existing configs** using `--compare` output
2. **Re-validate all configs** to ensure Table 3 compliance
3. **Add baseline results** from GuacaMol paper to database
4. **Link W&B runs** to benchmark database for meta-analysis
5. **Extend to non-GuacaMol benchmarks** (PIDGIN, docking, custom)

## Database Location

```
/home/ubuntu/mangodb/benchmark_db/
├── guacamol_benchmarks.db       # Main database
├── CONFIG_MAPPING_GUIDE.md      # How to use config mappings
├── CONFIG_MAPPING_SUMMARY.md    # This file
├── add_config_mappings.sql      # Schema extension
└── populate_config_mappings.sql # Config data
```

## Reference

**Database**: 20 benchmarks, 44 objectives, all mapped to config format
**Coverage**: 100% of Table 3 objectives
**Validation**: Catches parameter mismatches automatically
**Documentation**: Complete guide with examples

Use `python query_benchmarks.py --help` for all commands.
