-- Example SQL queries for GuacaMol Benchmark Database

-- ============================================================================
-- Basic Queries
-- ============================================================================

-- List all benchmarks
SELECT benchmark_name, category, scoring_type, aggregation_method
FROM benchmarks
ORDER BY category, benchmark_name;

-- Count benchmarks by category
SELECT category, COUNT(*) as count
FROM benchmarks
GROUP BY category
ORDER BY count DESC;

-- ============================================================================
-- Modifier Analysis
-- ============================================================================

-- All benchmarks using max_gaussian modifier
SELECT
    b.benchmark_name,
    sf.function_name,
    sf.modifier_mu as mu,
    sf.modifier_sigma as sigma
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.modifier_type = 'max_gaussian'
ORDER BY b.benchmark_name, sf.objective_order;

-- All benchmarks using min_gaussian modifier
SELECT
    b.benchmark_name,
    sf.function_name,
    sf.modifier_mu as mu,
    sf.modifier_sigma as sigma
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.modifier_type = 'min_gaussian'
ORDER BY b.benchmark_name, sf.objective_order;

-- Modifier usage statistics
SELECT modifier_type, COUNT(*) as usage_count
FROM scoring_functions
GROUP BY modifier_type
ORDER BY usage_count DESC;

-- ============================================================================
-- Property Analysis
-- ============================================================================

-- All benchmarks using TPSA
SELECT
    b.benchmark_name,
    sf.modifier_type,
    sf.modifier_mu,
    sf.modifier_sigma
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.function_type = 'tpsa'
ORDER BY b.benchmark_name;

-- All benchmarks using logP
SELECT
    b.benchmark_name,
    sf.modifier_type,
    sf.modifier_mu,
    sf.modifier_sigma
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.function_type = 'logp'
ORDER BY b.benchmark_name;

-- ============================================================================
-- Benchmark Complexity
-- ============================================================================

-- Benchmarks by number of objectives
SELECT
    b.benchmark_name,
    b.category,
    COUNT(sf.scoring_function_id) as num_objectives,
    b.aggregation_method
FROM benchmarks b
LEFT JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
GROUP BY b.benchmark_id
ORDER BY num_objectives DESC, b.benchmark_name;

-- Most complex benchmarks (4+ objectives)
SELECT
    b.benchmark_name,
    b.category,
    COUNT(sf.scoring_function_id) as num_objectives,
    GROUP_CONCAT(sf.function_name, ' | ') as objectives
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
GROUP BY b.benchmark_id
HAVING num_objectives >= 4
ORDER BY num_objectives DESC;

-- ============================================================================
-- Fexofenadine Example (November 19 Bug)
-- ============================================================================

-- Get complete Fexofenadine definition
SELECT * FROM benchmark_objectives
WHERE benchmark_name = 'Fexofenadine MPO'
ORDER BY objective_order;

-- Verify MaxGaussian parameters for TPSA
SELECT
    'TPSA' as property,
    'MaxGaussian' as modifier,
    modifier_mu as mu,
    modifier_sigma as sigma,
    'Values LARGER than mu get full score' as definition
FROM scoring_functions
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND function_name = 'TPSA';

-- Verify MinGaussian parameters for logP
SELECT
    'logP' as property,
    'MinGaussian' as modifier,
    modifier_mu as mu,
    modifier_sigma as sigma,
    'Values SMALLER than mu get full score' as definition
FROM scoring_functions
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND function_name = 'logP';

-- ============================================================================
-- Comparison Queries
-- ============================================================================

-- Compare all MPO benchmarks
SELECT
    b.benchmark_name,
    COUNT(sf.scoring_function_id) as num_objectives,
    SUM(CASE WHEN sf.function_type = 'similarity' THEN 1 ELSE 0 END) as num_similarity,
    SUM(CASE WHEN sf.function_type = 'tpsa' THEN 1 ELSE 0 END) as has_tpsa,
    SUM(CASE WHEN sf.function_type = 'logp' THEN 1 ELSE 0 END) as has_logp,
    SUM(CASE WHEN sf.function_type = 'count' THEN 1 ELSE 0 END) as num_counts,
    SUM(CASE WHEN sf.function_type = 'isomer' THEN 1 ELSE 0 END) as num_isomers
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE b.category = 'mpo'
GROUP BY b.benchmark_id
ORDER BY num_objectives DESC, b.benchmark_name;

-- Fingerprint usage across similarity objectives
SELECT
    fingerprint_type,
    COUNT(*) as usage_count,
    GROUP_CONCAT(DISTINCT b.benchmark_name) as used_in_benchmarks
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.function_type = 'similarity'
AND sf.fingerprint_type IS NOT NULL
GROUP BY fingerprint_type
ORDER BY usage_count DESC;

-- ============================================================================
-- SMARTS Pattern Analysis
-- ============================================================================

-- All SMARTS patterns with their abbreviations
SELECT
    sa.abbreviation,
    sa.description,
    sa.full_smarts
FROM smarts_abbreviations sa
ORDER BY sa.abbreviation;

-- Benchmarks using SMARTS patterns
SELECT
    b.benchmark_name,
    sf.function_name,
    sf.smarts_pattern,
    sf.smarts_present,
    CASE
        WHEN sf.smarts_present THEN 'Pattern required'
        ELSE 'Pattern forbidden'
    END as requirement
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
WHERE sf.function_type = 'smarts'
ORDER BY b.benchmark_name, sf.objective_order;
