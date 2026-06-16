/**
 * Cloudflare Worker: FFmpeg Processor
 * Handles audio extraction and WhatsApp video trimming via a server-side
 * FFmpeg API. Stores results in R2 and returns a public download URL.
 *
 * DEPLOY:
 *   wrangler deploy cloudflare/workers/ffmpeg_worker.js
 *
 * wrangler.toml additions:
 *   [[r2_buckets]]
 *   binding = "FFMPEG_BUCKET"
 *   bucket_name = "played-ffmpeg"
 *
 * SECRETS:
 *   APP_SECRET    — must match CloudflareConfig.workerSecret in Flutter
 *   FFMPEG_API_KEY — API key for server-side FFmpeg service (e.g. api.video)
 */

export default {
  async fetch(request, env) {
    if (request.headers.get('X-App-Secret') !== env.APP_SECRET) {
      return new Response('Unauthorized', { status: 401 });
    }

    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/process') {
      return handleProcess(request, env);
    }
    if (request.method === 'GET' && url.pathname.startsWith('/status/')) {
      const jobId = url.pathname.split('/status/')[1];
      return handleStatus(jobId, env);
    }

    return new Response('Not Found', { status: 404 });
  },
};

async function handleProcess(request, env) {
  const formData  = await request.formData();
  const file      = formData.get('file');
  const operation = formData.get('operation'); // 'extract_audio' | 'trim_whatsapp'
  const startSec  = parseFloat(formData.get('start_sec') || '0');
  const endSec    = parseFloat(formData.get('end_sec')   || '30');

  if (!file) {
    return Response.json({ error: 'No file provided' }, { status: 400 });
  }

  const jobId    = crypto.randomUUID();
  const inputKey = `jobs/${jobId}/input/${file.name}`;

  // Store input in R2
  await env.FFMPEG_BUCKET.put(inputKey, file.stream(), {
    httpMetadata: { contentType: file.type || 'video/mp4' },
  });

  // Store initial status
  await env.FFMPEG_BUCKET.put(`jobs/${jobId}/status.json`,
    JSON.stringify({ status: 'pending', created_at: new Date().toISOString() })
  );

  // Process asynchronously using Cloudflare Workflows
  await env.FFMPEG_WORKFLOW.create({
    id: jobId,
    params: { jobId, inputKey, operation, startSec, endSec, apiKey: env.FFMPEG_API_KEY },
  });

  return Response.json({ job_id: jobId, status: 'pending' });
}

async function handleStatus(jobId, env) {
  const obj = await env.FFMPEG_BUCKET.get(`jobs/${jobId}/status.json`);
  if (!obj) return Response.json({ error: 'Job not found' }, { status: 404 });
  return Response.json(await obj.json());
}
