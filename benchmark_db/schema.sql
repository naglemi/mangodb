-- GuacaMol Benchmark Database Schema
-- Faithfully reproduces Table 3 from GuacaMol paper (Brown et al. 2019)
-- https://arxiv.org/abs/1811.09621

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- ============================================================================
-- Core Tables
-- ============================================================================

-- Benchmarks: Top-level benchmark definitions
CREATE TABLE benchmarks (
    benchmark_id INTEGER PRIMARY KEY AUTOINCREMENT,
    benchmark_name TEXT NOT NULL UNIQUE,
    scoring_type TEXT NOT NULL,  -- 'top-1', 'top-10', 'top-100', 'top-159', 'top-250'
    aggregation_method TEXT,      -- 'geometric', 'arithmetic', NULL for single-objective
    category TEXT,                -- 'rediscovery', 'similarity', 'mpo', 'isomer', 'median', 'smarts', 'hop'
    description TEXT,
    paper_reference TEXT DEFAULT 'Brown et al. 2019 GuacaMol',

    -- Constraints
    CHECK (scoring_type IN ('top-1', 'top-10', 'top-100', 'top-159', 'top-250', 'top-1,top-10,top-100')),
    CHECK (aggregation_method IN ('geometric', 'arithmetic') OR aggregation_method IS NULL),
    CHECK (category IN ('rediscovery', 'similarity', 'mpo', 'isomer', 'median', 'smarts', 'hop'))
);

-- Scoring Functions: Individual objectives within benchmarks
CREATE TABLE scoring_functions (
    scoring_function_id INTEGER PRIMARY KEY AUTOINCREMENT,
    benchmark_id INTEGER NOT NULL,
    function_type TEXT NOT NULL,  -- 'similarity', 'tpsa', 'logp', 'isomer', 'smarts', 'count', 'bertz', 'qed'
    function_name TEXT NOT NULL,  -- e.g., 'sim(celecoxib, ECFP4)', 'TPSA', 'logP'
    target_molecule TEXT,         -- Target molecule name (for similarity functions)
    fingerprint_type TEXT,        -- 'ECFP4', 'ECFP6', 'FCFP4', 'AP', 'PHCO'
    property_name TEXT,           -- 'tpsa', 'logp', 'num_aromatic_rings', etc.
    smarts_pattern TEXT,          -- SMARTS pattern (for SMARTS functions)
    smarts_present BOOLEAN,       -- TRUE=pattern required, FALSE=pattern forbidden
    isomer_formula TEXT,          -- Molecular formula (for isomer functions)
    modifier_type TEXT,           -- 'none', 'gaussian', 'min_gaussian', 'max_gaussian', 'thresholded'
    modifier_mu REAL,             -- μ parameter for Gaussian modifiers
    modifier_sigma REAL,          -- σ parameter for Gaussian modifiers
    modifier_threshold REAL,      -- threshold parameter for Thresholded modifier
    objective_order INTEGER NOT NULL,  -- Order within the benchmark (1, 2, 3, ...)

    FOREIGN KEY (benchmark_id) REFERENCES benchmarks(benchmark_id) ON DELETE CASCADE,

    -- Constraints
    CHECK (function_type IN ('similarity', 'tpsa', 'logp', 'isomer', 'smarts', 'count', 'bertz', 'qed')),
    CHECK (fingerprint_type IN ('ECFP4', 'ECFP6', 'FCFP4', 'AP', 'PHCO') OR fingerprint_type IS NULL),
    CHECK (modifier_type IN ('none', 'gaussian', 'min_gaussian', 'max_gaussian', 'thresholded'))
);

-- SMARTS Abbreviations: Lookup table for abbreviated SMARTS patterns from paper
CREATE TABLE smarts_abbreviations (
    abbreviation TEXT PRIMARY KEY,
    full_smarts TEXT NOT NULL,
    description TEXT
);

-- Baseline Results: Performance of baseline models from GuacaMol paper
CREATE TABLE baseline_results (
    result_id INTEGER PRIMARY KEY AUTOINCREMENT,
    benchmark_id INTEGER NOT NULL,
    model_name TEXT NOT NULL,  -- 'Graph GA', 'SMILES LSTM', 'SMILES GA', 'Graph MCTS', 'Random', 'Best from Dataset'
    score REAL,                -- Final benchmark score
    notes TEXT,

    FOREIGN KEY (benchmark_id) REFERENCES benchmarks(benchmark_id) ON DELETE CASCADE,

    UNIQUE(benchmark_id, model_name)
);

-- ============================================================================
-- Views for Convenient Querying
-- ============================================================================

-- View: Complete benchmark definitions with all objectives
CREATE VIEW benchmark_objectives AS
SELECT
    b.benchmark_name,
    b.scoring_type,
    b.aggregation_method,
    b.category,
    sf.objective_order,
    sf.function_name,
    sf.function_type,
    sf.target_molecule,
    sf.fingerprint_type,
    sf.property_name,
    sf.smarts_pattern,
    sf.smarts_present,
    sf.isomer_formula,
    sf.modifier_type,
    sf.modifier_mu,
    sf.modifier_sigma,
    sf.modifier_threshold
FROM benchmarks b
JOIN scoring_functions sf ON b.benchmark_id = sf.benchmark_id
ORDER BY b.benchmark_name, sf.objective_order;

-- View: Benchmark summary with objective count
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

-- ============================================================================
-- Indexes for Performance
-- ============================================================================

CREATE INDEX idx_benchmarks_category ON benchmarks(category);
CREATE INDEX idx_benchmarks_name ON benchmarks(benchmark_name);
CREATE INDEX idx_scoring_functions_benchmark ON scoring_functions(benchmark_id);
CREATE INDEX idx_scoring_functions_type ON scoring_functions(function_type);
CREATE INDEX idx_baseline_results_benchmark ON baseline_results(benchmark_id);
CREATE INDEX idx_baseline_results_model ON baseline_results(model_name);
