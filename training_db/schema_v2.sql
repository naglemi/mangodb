-- Training Database Schema v2: Flexible Multi-Objective Support
-- Handles ~200 W&B attributes with hybrid storage approach

-- ============================================================================
-- MAIN TABLE: training_runs (UPGRADED from v1)
-- ============================================================================

CREATE TABLE IF NOT EXISTS training_runs (
  -- ========== Identity ==========
  run_id TEXT PRIMARY KEY,
  wandb_run_id TEXT UNIQUE,
  run_name TEXT,
  chain_of_custody_id TEXT,  -- Links conversation → training → crash → analysis

  -- ========== Configuration Metadata ==========
  config_file_path TEXT,
  host TEXT,  -- 'expanse' or 'ec2'
  instance_id TEXT,  -- EC2 instance ID or Expanse job ID

  -- ========== Timestamps ==========
  created_at TIMESTAMP,  -- When run record created (from W&B or at launch)
  started_at TIMESTAMP,  -- When training actually started
  ended_at TIMESTAMP,    -- When training finished/crashed
  duration_seconds INTEGER,  -- Total runtime

  -- ========== Status ==========
  status TEXT DEFAULT 'launched',  -- launched, running, completed, failed, crashed

  -- ========== Extracted Hyperparameters (Top 20 for fast queries) ==========
  -- Training basics
  batch_size INTEGER,
  learning_rate REAL,
  gradient_accumulation_steps INTEGER,
  max_steps INTEGER,
  max_grad_norm REAL,

  -- Multi-objective specifics
  gradient_method TEXT,  -- mgda, pcgrad, imtlg, aligned_mtl, cagrad, etc.
  beta REAL,  -- For methods that use beta parameter
  num_objectives INTEGER,
  num_scaffolds INTEGER,

  -- Architecture/optimization
  num_gpus INTEGER,
  mixed_precision BOOLEAN,
  gradient_checkpointing BOOLEAN,
  fp16 BOOLEAN,
  bf16 BOOLEAN,

  -- Reward/grouping settings
  enable_moving_targets BOOLEAN,
  return_groups BOOLEAN,
  n_clusters INTEGER,

  -- ========== Extracted Training Metrics ==========
  final_loss REAL,
  final_grad_norm REAL,
  final_learning_rate REAL,
  total_training_steps INTEGER,

  -- ========== Flexible Storage (JSON - ALL ~200 attributes) ==========
  -- Full config from YAML (50-100 attributes)
  config_json TEXT,  -- Stores entire config dict as JSON

  -- Full W&B summary (100-150 attributes)
  final_metrics_json TEXT,  -- Stores wandb.run.summary._json_dict

  -- ========== Attachments (S3 keys) ==========
  conversation_s3_key TEXT,  -- Conversation export for this run
  crash_report_s3_key TEXT,  -- Crash report markdown
  error_log_s3_key TEXT,  -- Error log file
  crash_analysis_s3_key TEXT,  -- Bedrock crash analysis
  blog_post_url TEXT,  -- Blog post URL (if created)

  -- ========== W&B Metadata ==========
  wandb_url TEXT,  -- Direct link to W&B run

  -- ========== Audit ==========
  created_at_db TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at_db TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_gradient_method ON training_runs(gradient_method);
CREATE INDEX IF NOT EXISTS idx_status ON training_runs(status);
CREATE INDEX IF NOT EXISTS idx_host ON training_runs(host);
CREATE INDEX IF NOT EXISTS idx_created_at ON training_runs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_batch_size ON training_runs(batch_size);
CREATE INDEX IF NOT EXISTS idx_learning_rate ON training_runs(learning_rate);
CREATE INDEX IF NOT EXISTS idx_num_objectives ON training_runs(num_objectives);
CREATE INDEX IF NOT EXISTS idx_chain_of_custody ON training_runs(chain_of_custody_id);

-- ============================================================================
-- NEW TABLE: run_objectives
-- ============================================================================
-- Stores per-objective configuration and final values
-- Enables queries like: "find runs where COMT_activity > 0.8"

CREATE TABLE IF NOT EXISTS run_objectives (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,

  -- ========== Objective Identification ==========
  objective_name TEXT NOT NULL,  -- e.g., "DRD5_activity", "COMT_activity", "QED"
  objective_alias TEXT,          -- e.g., "DRD5_activity_maximize" (how it appears in W&B)
  uniprot TEXT,                  -- e.g., "P21918" (for protein targets)

  -- ========== Objective Configuration (from config YAML) ==========
  weight REAL,
  direction TEXT,  -- 'maximize' or 'minimize'

  -- ========== Final Values (from W&B summary) ==========
  -- These come from: objectives/{objective_alias}/{metric_type}
  raw_mean REAL,              -- Final raw mean value
  normalized_mean REAL,       -- Final normalized mean value
  raw_std REAL,               -- Standard deviation (raw)
  normalized_std REAL,        -- Standard deviation (normalized)

  -- ========== Metadata ==========
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (run_id) REFERENCES training_runs(run_id) ON DELETE CASCADE
);

-- Indexes for objective queries
CREATE INDEX IF NOT EXISTS idx_obj_run_id ON run_objectives(run_id);
CREATE INDEX IF NOT EXISTS idx_obj_name ON run_objectives(objective_name);
CREATE INDEX IF NOT EXISTS idx_obj_raw_mean ON run_objectives(raw_mean);
CREATE INDEX IF NOT EXISTS idx_obj_normalized_mean ON run_objectives(normalized_mean);
CREATE INDEX IF NOT EXISTS idx_obj_direction ON run_objectives(direction);
CREATE UNIQUE INDEX IF NOT EXISTS idx_obj_run_name ON run_objectives(run_id, objective_name);

-- ============================================================================
-- FUTURE TABLE: run_scaffolds (Phase 3)
-- ============================================================================
-- Commented out for now - add when we need per-scaffold tracking
/*
CREATE TABLE IF NOT EXISTS run_scaffolds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  scaffold_id TEXT NOT NULL,

  -- Per-scaffold scores for each objective (JSON)
  -- Example: {"DRD5_activity": 0.85, "COMT_activity": 0.72, "QED": 0.68}
  scores_json TEXT,

  -- Pareto/clustering info
  pareto_rank INTEGER,
  cluster_id INTEGER,
  is_pareto_optimal BOOLEAN,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (run_id) REFERENCES training_runs(run_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_scaffold_run_id ON run_scaffolds(run_id);
CREATE INDEX IF NOT EXISTS idx_scaffold_pareto ON run_scaffolds(is_pareto_optimal);
CREATE UNIQUE INDEX IF NOT EXISTS idx_scaffold_run_scaffold ON run_scaffolds(run_id, scaffold_id);
*/

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
--
-- To upgrade from v1 to v2:
-- 1. Create run_objectives table (new)
-- 2. Add new columns to training_runs (ALTER TABLE)
-- 3. Backfill objectives from existing runs' config_json
-- 4. Backfill objective values from existing runs' final_metrics_json
--
-- SQL for migration:
--
-- -- Add new columns to training_runs
-- ALTER TABLE training_runs ADD COLUMN gradient_accumulation_steps INTEGER;
-- ALTER TABLE training_runs ADD COLUMN max_steps INTEGER;
-- ALTER TABLE training_runs ADD COLUMN max_grad_norm REAL;
-- ALTER TABLE training_runs ADD COLUMN mixed_precision BOOLEAN;
-- ALTER TABLE training_runs ADD COLUMN gradient_checkpointing BOOLEAN;
-- ALTER TABLE training_runs ADD COLUMN fp16 BOOLEAN;
-- ALTER TABLE training_runs ADD COLUMN bf16 BOOLEAN;
-- ALTER TABLE training_runs ADD COLUMN enable_moving_targets BOOLEAN;
-- ALTER TABLE training_runs ADD COLUMN return_groups BOOLEAN;
-- ALTER TABLE training_runs ADD COLUMN n_clusters INTEGER;
-- ALTER TABLE training_runs ADD COLUMN final_loss REAL;
-- ALTER TABLE training_runs ADD COLUMN final_grad_norm REAL;
-- ALTER TABLE training_runs ADD COLUMN final_learning_rate REAL;
-- ALTER TABLE training_runs ADD COLUMN total_training_steps INTEGER;
--
-- -- Create objectives table
-- [run the CREATE TABLE run_objectives statement above]
--
-- -- Backfill will be done by Python script (see migration.py)

-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================

-- Query 1: Find all MGDA runs with COMT > 0.8
/*
SELECT DISTINCT r.*
FROM training_runs r
JOIN run_objectives o ON r.run_id = o.run_id
WHERE r.gradient_method = 'mgda'
  AND r.status = 'completed'
  AND o.objective_name = 'COMT_activity'
  AND o.raw_mean > 0.8
ORDER BY r.created_at DESC;
*/

-- Query 2: Compare gradient methods on DRD5 performance
/*
SELECT
  r.gradient_method,
  COUNT(*) as num_runs,
  AVG(o.raw_mean) as avg_drd5,
  MAX(o.raw_mean) as best_drd5,
  AVG(r.duration_seconds / 3600.0) as avg_hours
FROM training_runs r
JOIN run_objectives o ON r.run_id = o.run_id
WHERE o.objective_name = 'DRD5_activity'
  AND r.status = 'completed'
  AND r.gradient_method IS NOT NULL
GROUP BY r.gradient_method
ORDER BY avg_drd5 DESC;
*/

-- Query 3: Find runs with good multi-objective balance
/*
SELECT r.run_id, r.run_name, r.gradient_method,
       o1.raw_mean as comt,
       o2.raw_mean as drd5,
       o3.raw_mean as qed
FROM training_runs r
JOIN run_objectives o1 ON r.run_id = o1.run_id AND o1.objective_name = 'COMT_activity'
JOIN run_objectives o2 ON r.run_id = o2.run_id AND o2.objective_name = 'DRD5_activity'
JOIN run_objectives o3 ON r.run_id = o3.run_id AND o3.objective_name = 'QED'
WHERE r.status = 'completed'
  AND o1.raw_mean > 0.75
  AND o2.raw_mean > 0.70
  AND o3.raw_mean > 0.65
ORDER BY (o1.raw_mean + o2.raw_mean + o3.raw_mean) DESC
LIMIT 20;
*/

-- Query 4: Find runs by specific config parameters (JSON extraction)
/*
SELECT
  run_id,
  run_name,
  json_extract(config_json, '$.training.gradient_accumulation_steps') as gas,
  json_extract(config_json, '$.training.max_grad_norm') as grad_clip
FROM training_runs
WHERE json_extract(config_json, '$.training.gradient_accumulation_steps') > 4
  AND status = 'completed';
*/

-- Query 5: Analyze crash patterns by gradient method
/*
SELECT
  gradient_method,
  COUNT(*) as total_runs,
  SUM(CASE WHEN status = 'crashed' THEN 1 ELSE 0 END) as crashes,
  ROUND(100.0 * SUM(CASE WHEN status = 'crashed' THEN 1 ELSE 0 END) / COUNT(*), 1) as crash_rate_pct
FROM training_runs
WHERE gradient_method IS NOT NULL
GROUP BY gradient_method
ORDER BY crash_rate_pct DESC;
*/

-- Query 6: Find runs without blog posts that have good results
/*
SELECT r.run_id, r.run_name, r.gradient_method, r.duration_seconds / 3600.0 as hours,
       AVG(o.raw_mean) as avg_objective_score
FROM training_runs r
JOIN run_objectives o ON r.run_id = o.run_id
WHERE r.status = 'completed'
  AND r.blog_post_url IS NULL
  AND r.duration_seconds > 7200  -- > 2 hours
GROUP BY r.run_id
HAVING avg_objective_score > 0.70
ORDER BY avg_objective_score DESC
LIMIT 20;
*/
