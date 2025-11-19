-- Add config mapping columns to scoring_functions table
-- Shows exactly how each GuacaMol objective should be represented in our training configs

BEGIN TRANSACTION;

-- Add new columns for config representation
ALTER TABLE scoring_functions ADD COLUMN config_name TEXT;
ALTER TABLE scoring_functions ADD COLUMN config_alias TEXT;
ALTER TABLE scoring_functions ADD COLUMN config_direction TEXT CHECK (config_direction IN ('maximize', 'minimize'));
ALTER TABLE scoring_functions ADD COLUMN config_notes TEXT;

-- Update the benchmark_objectives view to include config mappings
DROP VIEW IF EXISTS benchmark_objectives;

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
    -- Config representation
    sf.config_name,
    sf.config_alias,
    sf.config_direction,
    sf.config_notes
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
ORDER BY b.benchmark_name, sf.objective_order;

-- Create new view showing Table 3 vs Config comparison
CREATE VIEW table3_vs_config AS
SELECT
    b.benchmark_name,
    sf.objective_order,
    -- Table 3 representation
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
    -- Config representation
    sf.config_name,
    sf.config_alias,
    sf.config_direction,
    sf.modifier_type as config_modifier,
    -- Comparison
    CASE
        WHEN sf.config_name IS NULL THEN 'NOT MAPPED'
        WHEN sf.config_notes IS NOT NULL THEN 'HAS NOTES'
        ELSE 'OK'
    END as status,
    sf.config_notes
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
ORDER BY b.benchmark_name, sf.objective_order;

COMMIT;
