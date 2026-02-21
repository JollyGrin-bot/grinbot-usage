# Usage Tracker (VPS Side)

This directory contains scripts that run on the VPS to track API usage and generate the public dashboard data.

## Files

- `schema.sql` — SQLite database schema
- `log-usage.sh` — Log a single API call
- `aggregate-usage.sh` — Generate public usage.json from database

## Database Location

`~/.openclaw/usage.db` (private, not committed)

## Usage

### Log an API call manually

```bash
./log-usage.sh \
  --model "kimi-k2.5" \
  --input-tokens 1000 \
  --output-tokens 500 \
  --duration 1200
```

### Generate dashboard data

```bash
./aggregate-usage.sh
```

This updates `../data/usage.json` which is committed to the repo.

## Integration with OpenClaw

The logging should be integrated into OpenClaw's API call flow. When an API call completes:

1. Extract model name, token counts, duration
2. Call `log-usage.sh` with the data
3. Run `aggregate-usage.sh` periodically (cron) to update the dashboard

## Pricing

Edit `model_pricing` table in SQLite to update rates:

```sql
INSERT OR REPLACE INTO model_pricing (model, input_price, output_price) 
VALUES ('new-model', 1.00, 2.00);
```

Prices are per 1M tokens in USD. Converted to EUR in aggregations.
