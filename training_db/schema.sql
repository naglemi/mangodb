-- Training Runs Database Schema v1.0
-- SQLite version (will migrate to PostgreSQL when we get RDS permissions)

CREATE TABLE IF NOT EXISTS training_runs (
  -- Primary identification
  run_id TEXT PRIMARY KEY,
  wandb_run_id TEXT UNIQUE,
  wandb_url TEXT,
  run_name TEXT,

  -- Tracking IDs
  chain_of_custody_id TEXT,

  -- Basic metadata
  config_file_path TEXT,
  host TEXT,
  instance_id TEXT,

  -- Timestamps (stored as ISO 8601 strings in SQLite)
  created_at TEXT,
  started_at TEXT,
  ended_at TEXT,

  -- Status (binary: running or not_running)
  status TEXT DEFAULT 'running',
  duration_seconds INTEGER,

  -- Key hyperparameters (most-queried fields)
  batch_size INTEGER,
  learning_rate REAL,
  beta REAL,
  gradient_method TEXT,
  num_gpus INTEGER,
  num_objectives INTEGER,
  num_scaffolds INTEGER,

  -- Flexible storage (JSONB equivalent in SQLite)
  config_json TEXT,
  final_metrics_json TEXT,

  -- Attachments (added at various lifecycle points)
  blog_post_url TEXT,
  conversation_s3_key TEXT,
  crash_report_s3_key TEXT,
  error_log_s3_key TEXT,
  crash_analysis_s3_key TEXT,

  -- Audit
  created_at_db TEXT DEFAULT (datetime('now')),
  updated_at_db TEXT DEFAULT (datetime('now'))
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_runs_status ON training_runs(status);
CREATE INDEX IF NOT EXISTS idx_runs_host ON training_runs(host);
CREATE INDEX IF NOT EXISTS idx_runs_gradient_method ON training_runs(gradient_method);
CREATE INDEX IF NOT EXISTS idx_runs_created_at ON training_runs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_runs_chain_of_custody ON training_runs(chain_of_custody_id);

-- Trigger to auto-update updated_at_db
CREATE TRIGGER IF NOT EXISTS update_runs_updated_at
AFTER UPDATE ON training_runs
FOR EACH ROW
BEGIN
  UPDATE training_runs SET updated_at_db = datetime('now')
  WHERE run_id = NEW.run_id;
END;
