-- GrinBot Usage Tracker Schema
-- SQLite database for tracking API usage and costs

-- Main table: every API call logged
CREATE TABLE IF NOT EXISTS api_calls (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL DEFAULT (datetime('now')),
  date TEXT NOT NULL DEFAULT (date('now')),
  model TEXT NOT NULL,
  provider TEXT,
  input_tokens INTEGER DEFAULT 0,
  output_tokens INTEGER DEFAULT 0,
  cost REAL DEFAULT 0,
  duration_ms INTEGER,
  status TEXT DEFAULT 'success',
  session_key TEXT
);

-- Index for fast date queries
CREATE INDEX IF NOT EXISTS idx_api_calls_date ON api_calls(date);
CREATE INDEX IF NOT EXISTS idx_api_calls_model ON api_calls(model);
CREATE INDEX IF NOT EXISTS idx_api_calls_timestamp ON api_calls(timestamp);

-- Table for model pricing (per 1M tokens)
CREATE TABLE IF NOT EXISTS model_pricing (
  model TEXT PRIMARY KEY,
  input_price REAL NOT NULL,  -- per 1M input tokens
  output_price REAL NOT NULL, -- per 1M output tokens
  updated_at TEXT DEFAULT (datetime('now'))
);

-- Insert default pricing (Kimi K2.5)
-- Prices in USD, converted to EUR in aggregations
INSERT OR REPLACE INTO model_pricing (model, input_price, output_price) VALUES
  ('kimi-k2.5', 0.50, 2.00),
  ('gpt-4', 30.00, 60.00),
  ('gpt-4o', 5.00, 15.00),
  ('claude-3-opus', 15.00, 75.00),
  ('claude-3-sonnet', 3.00, 15.00),
  ('claude-3-haiku', 0.25, 1.25);