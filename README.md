# GrinBot Usage Dashboard

Track AI model usage and costs — static site hosted on GitHub Pages.

## Data Flow

```
OpenClaw API calls → SQLite (private) → Aggregator → usage.json (public) → GitHub Pages
```

## Structure

- `data/usage.json` — Aggregated daily/monthly stats (committed to repo)
- `index.html` — Dashboard visualization
- `tracker/` — SQLite schema and logging (private, on VPS)

## Privacy

- No API keys exposed
- No request content logged
- Only metadata: model, tokens, timestamp, cost

## Deployment

Automatically deployed to GitHub Pages on every push to `main`.
