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
  cat > "$OUTPUT_FILE" << EOF
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

# Generate aggregated data using sqlite3 and Python for JSON
python3 << PYEOF
import sqlite3
import json
from datetime import datetime

DB_PATH = "$DB_PATH"
USD_TO_EUR = $USD_TO_EUR

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# Get total stats
cursor.execute("SELECT COUNT(*), COALESCE(SUM(cost), 0) FROM api_calls")
total_requests, total_cost_usd = cursor.fetchone()

# Get active models
cursor.execute("SELECT DISTINCT model FROM api_calls")
active_models = [row[0] for row in cursor.fetchall()]

# Get daily stats (last 90 days)
cursor.execute("""
  SELECT date, model, COUNT(*), SUM(input_tokens), SUM(output_tokens), SUM(cost)
  FROM api_calls
  WHERE date >= date('now', '-90 days')
  GROUP BY date, model
  ORDER BY date
""")
daily = []
for row in cursor.fetchall():
  daily.append({
    "date": row[0],
    "model": row[1],
    "requests": row[2],
    "inputTokens": row[3] or 0,
    "outputTokens": row[4] or 0,
    "cost": round((row[5] or 0) * USD_TO_EUR, 2)
  })

# Get monthly stats
cursor.execute("""
  SELECT strftime('%Y-%m', date) as month, model, COUNT(*), SUM(input_tokens), SUM(output_tokens), SUM(cost)
  FROM api_calls
  GROUP BY strftime('%Y-%m', date), model
  ORDER BY month
""")
monthly = []
for row in cursor.fetchall():
  monthly.append({
    "month": row[0],
    "model": row[1],
    "requests": row[2],
    "inputTokens": row[3] or 0,
    "outputTokens": row[4] or 0,
    "cost": round((row[5] or 0) * USD_TO_EUR, 2)
  })

# Get model totals
cursor.execute("""
  SELECT model, COUNT(*), SUM(input_tokens), SUM(output_tokens), SUM(cost)
  FROM api_calls
  GROUP BY model
""")
models = {}
for row in cursor.fetchall():
  models[row[0]] = {
    "requests": row[1],
    "inputTokens": row[2] or 0,
    "outputTokens": row[3] or 0,
    "totalCost": round((row[4] or 0) * USD_TO_EUR, 2)
  }

conn.close()

result = {
  "generatedAt": datetime.utcnow().isoformat() + "Z",
  "summary": {
    "totalCost": round(total_cost_usd * USD_TO_EUR, 2),
    "totalRequests": total_requests,
    "activeModels": active_models
  },
  "monthly": monthly,
  "daily": daily,
  "models": models
}

with open("$OUTPUT_FILE", "w") as f:
  json.dump(result, f, indent=2)

print(f"Generated $OUTPUT_FILE")
print(f"Total cost: €{result['summary']['totalCost']:.2f}")
print(f"Total requests: {result['summary']['totalRequests']}")
PYEOF