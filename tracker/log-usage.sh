#!/bin/bash
# log-usage.sh
# Log an API call to the usage database
# Usage: ./log-usage.sh --model "kimi-k2.5" --input-tokens 1000 --output-tokens 500 [--duration 1200] [--status success]

DB_PATH="${HOME}/.openclaw/usage.db"
MODEL=""
INPUT_TOKENS=0
OUTPUT_TOKENS=0
DURATION_MS=""
STATUS="success"
PROVIDER=""
SESSION_KEY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --model)
      MODEL="$2"
      shift 2
      ;;
    --input-tokens)
      INPUT_TOKENS="$2"
      shift 2
      ;;
    --output-tokens)
      OUTPUT_TOKENS="$2"
      shift 2
      ;;
    --duration)
      DURATION_MS="$2"
      shift 2
      ;;
    --status)
      STATUS="$2"
      shift 2
      ;;
    --provider)
      PROVIDER="$2"
      shift 2
      ;;
    --session-key)
      SESSION_KEY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ -z "$MODEL" ]; then
  echo "Error: --model is required"
  exit 1
fi

# Initialize database if needed
if [ ! -f "$DB_PATH" ]; then
  mkdir -p "$(dirname "$DB_PATH")"
  sqlite3 "$DB_PATH" < "$(dirname "$0")/schema.sql"
fi

# Calculate cost using Python (no jq needed)
COST_USD=$(python3 << EOF
import sqlite3
conn = sqlite3.connect("$DB_PATH")
cursor = conn.cursor()
cursor.execute("SELECT input_price, output_price FROM model_pricing WHERE model = ?", ("$MODEL",))
row = cursor.fetchone()
if row:
  cost = ($INPUT_TOKENS * row[0] / 1000000.0) + ($OUTPUT_TOKENS * row[1] / 1000000.0)
  print(cost)
else:
  print(0)
conn.close()
EOF
)

# Insert the log entry
sqlite3 "$DB_PATH" << EOF
INSERT INTO api_calls 
  (model, provider, input_tokens, output_tokens, cost, duration_ms, status, session_key)
VALUES 
  ('$MODEL', '${PROVIDER:-}', $INPUT_TOKENS, $OUTPUT_TOKENS, ${COST_USD:-0}, ${DURATION_MS:-NULL}, '$STATUS', '${SESSION_KEY:-}');
EOF

COST_EUR=$(echo "$COST_USD * 0.92" | bc -l)
printf "Logged: %s | %d in / %d out | €%.4f\n" "$MODEL" "$INPUT_TOKENS" "$OUTPUT_TOKENS" "$COST_EUR"