#!/bin/bash
# aggregate-usage.sh
# Aggregate API usage data and generate public usage.json

set -e

DB_PATH="${HOME}/.openclaw/usage.db"
OUTPUT_DIR="/home/claw/.openclaw/workspace/grinbot-usage/data"
OUTPUT_FILE="$OUTPUT_DIR/usage.json"
USD_TO_EUR="0.92"  # Approximate rate, update as needed

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
  echo "No usage database found at $DB_PATH"
  echo "Creating empty usage.json"
  cat > "$OUTPUT_FILE" << 'EOF'
{
  "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "summary": {
    "totalCost": 0,
    "totalRequests": 0,
    "activeModels": []
  },
  "monthly": [],
  "daily": [],
  "models": {}
}
EOF
  exit 0
fi

# Generate aggregated data using sqlite3
sqlite3 "$DB_PATH" << EOF | jq . > "$OUTPUT_FILE"
WITH 
-- Daily aggregates
daily_stats AS (
  SELECT 
    date,
    model,
    COUNT(*) as requests,
    SUM(input_tokens) as input_tokens,
    SUM(output_tokens) as output_tokens,
    SUM(cost) as cost_usd
  FROM api_calls
  WHERE date >= date('now', '-90 days')
  GROUP BY date, model
),
-- Monthly aggregates  
monthly_stats AS (
  SELECT 
    strftime('%Y-%m', date) as month,
    model,
    COUNT(*) as requests,
    SUM(input_tokens) as input_tokens,
    SUM(output_tokens) as output_tokens,
    SUM(cost) as cost_usd
  FROM api_calls
  GROUP BY strftime('%Y-%m', date), model
),
-- Model totals
model_totals AS (
  SELECT 
    model,
    COUNT(*) as requests,
    SUM(input_tokens) as input_tokens,
    SUM(output_tokens) as output_tokens,
    SUM(cost) as cost_usd
  FROM api_calls
  GROUP BY model
),
-- Overall totals
total_stats AS (
  SELECT 
    COUNT(*) as total_requests,
    SUM(cost) as total_cost_usd
  FROM api_calls
)
SELECT json_object(
  'generatedAt', datetime('now'),
  'summary', json_object(
    'totalCost', ROUND((SELECT total_cost_usd FROM total_stats) * $USD_TO_EUR, 2),
    'totalRequests', (SELECT total_requests FROM total_stats),
    'activeModels', (SELECT json_group_array(DISTINCT model) FROM api_calls)
  ),
  'monthly', COALESCE((
    SELECT json_group_array(json_object(
      'month', month,
      'model', model,
      'requests', requests,
      'inputTokens', input_tokens,
      'outputTokens', output_tokens,
      'cost', ROUND(cost_usd * $USD_TO_EUR, 2)
    ))
    FROM monthly_stats
  ), '[]'),
  'daily', COALESCE((
    SELECT json_group_array(json_object(
      'date', date,
      'model', model,
      'requests', requests,
      'inputTokens', input_tokens,
      'outputTokens', output_tokens,
      'cost', ROUND(cost_usd * $USD_TO_EUR, 2)
    ))
    FROM daily_stats
  ), '[]'),
  'models', COALESCE((
    SELECT json_object(
      model, json_object(
        'requests', requests,
        'inputTokens', input_tokens,
        'outputTokens', output_tokens,
        'totalCost', ROUND(cost_usd * $USD_TO_EUR, 2)
      )
    )
    FROM model_totals
  ), '{}')
);
EOF

echo "Generated $OUTPUT_FILE"
echo "Total cost: $(jq -r '.summary.totalCost' "$OUTPUT_FILE") EUR"
echo "Total requests: $(jq -r '.summary.totalRequests' "$OUTPUT_FILE")"