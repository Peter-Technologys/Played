/**
 * Cloudflare Worker: Stem Splitter
 * Receives audio uploads from the PLAYED app, stores them in R2,
 * triggers a Cloudflare Workflow for Demucs processing, and returns a job_id.
 *
 * DEPLOY:
 *   1. Install Wrangler: npm install -g wrangler
 *   2. wrangler login
 *   3. wrangler deploy cloudflare/workers/stem_splitter.js
 *
 * wrangler.toml (create in project root):
 *   name = "played-stem-splitter"
 *   main = "cloudflare/workers/stem_splitter.js"
 *   compatibility_date = "2024-01-01"
 *   [[r2_buckets]]
 *   binding = "STEMS_BUCKET"
 *   bucket_name = "played-stems"
 *
 * SECRETS (set via: wrangler secret put SECRET_NAME):
 *   APP_SECRET     — must match CloudflareConfig.workerSecret in Flutter
 *   SPLEETER_KEY   — API key for your stem-splitting service (e.g. lalal.ai)
 */

export default {
  async fetch(request, env) {
    // Auth check
    if (request.headers.get('X-App-Secret') !== env.APP_SECRET) {
      return new Response('Unauthorized', { status: 401 });
    }

    const url = new URL(request.url);

    // POST /split — upload audio + trigger Workflow
    if (request.method === 'POST' && url.pathname === '/split') {
      return handleSplit(request, env);
    }

    // GET /status/:jobId — poll Workflow status
    if (request.method === 'GET' && url.pathname.startsWith('/status/')) {
      const jobId = url.pathname.split('/status/')[1];
      return handleStatus(jobId, env);
    }

    return new Response('Not Found', { status: 404 });
  },
};

async function handleSplit(request, env) {
  const formData = await request.formData();
  const audioFile = formData.get('audio');
  const model = formData.get('model') || 'htdemucs';

  if (!audioFile) {
    return Response.json({ error: 'No audio file provided' }, { status: 400 });
  }

  // Generate unique job ID
  const jobId = crypto.randomUUID();

  // Store uploaded file in R2
  const inputKey = `jobs/${jobId}/input/${audioFile.name}`;
  await env.STEMS_BUCKET.put(inputKey, audioFile.stream(), {
    httpMetadata: { contentType: audioFile.type || 'audio/mpeg' },
  });

  // Store initial job status in R2
  await env.STEMS_BUCKET.put(`jobs/${jobId}/status.json`,
    JSON.stringify({ status: 'pending', created_at: new Date().toISOString() })
  );

  // Trigger Cloudflare Workflow (durable, survives Worker restarts)
  // The Workflow handles the actual Demucs API call asynchronously.
  await env.STEM_WORKFLOW.create({
    id: jobId,
    params: { jobId, inputKey, model, apiKey: env.SPLEETER_KEY },
  });

  return Response.json({ job_id: jobId, status: 'pending' });
}

async function handleStatus(jobId, env) {
  const statusObj = await env.STEMS_BUCKET.get(`jobs/${jobId}/status.json`);
  if (!statusObj) {
    return Response.json({ error: 'Job not found' }, { status: 404 });
  }
  const status = await statusObj.json();
  return Response.json(status);
}
