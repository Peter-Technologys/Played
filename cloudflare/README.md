# Cloudflare Integration for PLAYED

This directory contains the Cloudflare Workers and Workflows that power
the Studio stem-splitting and FFmpeg features in the PLAYED app.

## Architecture

```
Flutter App
    │
    ├── POST /split ──────────────► Stem Splitter Worker
    │                                    │
    │                                    ├── Stores input in R2
    │                                    └── Triggers StemWorkflow
    │                                              │
    │                                              ├── Calls lalal.ai / moises.ai
    │                                              ├── Downloads stems
    │                                              └── Stores in R2
    │
    ├── GET /status/:jobId ────────► Stem Splitter Worker
    │                                    └── Reads status.json from R2
    │
    └── Downloads stems ──────────► R2 Public URL
```

## Setup

### 1. Install Wrangler
```bash
npm install -g wrangler
wrangler login
```

### 2. Create R2 Buckets
```bash
wrangler r2 bucket create played-stems
wrangler r2 bucket create played-ffmpeg
```

### 3. Create wrangler.toml in project root
```toml
name = "played-stem-splitter"
main = "cloudflare/workers/stem_splitter.js"
compatibility_date = "2024-01-01"

[[r2_buckets]]
binding = "STEMS_BUCKET"
bucket_name = "played-stems"

[[workflows]]
name = "stem-workflow"
binding = "STEM_WORKFLOW"
class_name = "StemWorkflow"
```

### 4. Set Secrets
```bash
wrangler secret put APP_SECRET
# Enter the same value as CloudflareConfig.workerSecret in Flutter

wrangler secret put SPLEETER_KEY
# Enter your lalal.ai or moises.ai API key
```

### 5. Deploy
```bash
wrangler deploy cloudflare/workers/stem_splitter.js
wrangler deploy cloudflare/workers/ffmpeg_worker.js
wrangler deploy cloudflare/workflows/stem_workflow.js
```

### 6. Update Flutter Config
Edit `lib/core/services/cloudflare_config.dart` and replace:
- `YOUR_SUBDOMAIN` with your Cloudflare Workers subdomain
- `YOUR_BUCKET_ID` with your R2 bucket public ID

### 7. Enable R2 Public Access
In Cloudflare Dashboard → R2 → played-stems → Settings → Public Access → Enable

## Stem Splitting Services

Choose one of these APIs for the Workflow:

| Service | Free Tier | Quality | API Docs |
|---------|-----------|---------|----------|
| [lalal.ai](https://www.lalal.ai) | 90 min/month | ⭐⭐⭐⭐⭐ | [docs](https://www.lalal.ai/api/) |
| [moises.ai](https://moises.ai) | 5 songs/month | ⭐⭐⭐⭐ | [docs](https://developer.moises.ai) |
| [audio.removeai](https://www.remove.bg) | Limited | ⭐⭐⭐ | — |

## Cost Estimate

| Service | Free Tier | Paid |
|---------|-----------|------|
| Cloudflare Workers | 100k req/day | $5/month for 10M req |
| Cloudflare R2 | 10 GB storage | $0.015/GB/month |
| Cloudflare Workflows | 1k runs/month | $0.001/run |
| lalal.ai | 90 min/month | ~$10/month |
