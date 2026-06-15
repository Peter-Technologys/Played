/**
 * Cloudflare Workflow: Stem Splitter
 * Durable execution — survives Worker restarts and network drops.
 * Each step is retried automatically on failure.
 *
 * DEPLOY:
 *   wrangler deploy cloudflare/workflows/stem_workflow.js
 *
 * wrangler.toml additions:
 *   [[workflows]]
 *   name = "stem-workflow"
 *   binding = "STEM_WORKFLOW"
 *   class_name = "StemWorkflow"
 */

import { WorkflowEntrypoint } from 'cloudflare:workers';

export class StemWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    const { jobId, inputKey, model, apiKey } = event.payload;

    // Step 1: Get a public URL for the input file from R2
    const inputUrl = await step.do('get-input-url', async () => {
      // Generate a pre-signed R2 URL valid for 1 hour
      const obj = await this.env.STEMS_BUCKET.get(inputKey);
      if (!obj) throw new Error('Input file not found in R2');
      // In production: use R2 presigned URLs or Workers Sites
      return `https://your-r2-public-url/${inputKey}`;
    });

    // Step 2: Call stem-splitting API (e.g. lalal.ai, moises.ai)
    const stemUrls = await step.do('split-stems', { retries: { limit: 3 } }, async () => {
      // Example using lalal.ai API — replace with your preferred service
      const uploadResp = await fetch('https://www.lalal.ai/api/upload/', {
        method: 'POST',
        headers: { 'Authorization': `license ${apiKey}` },
        body: JSON.stringify({ url: inputUrl }),
      });
      const { id: fileId } = await uploadResp.json();

      // Poll lalal.ai until processing is complete
      for (let i = 0; i < 30; i++) {
        await new Promise(r => setTimeout(r, 10000)); // wait 10s
        const checkResp = await fetch(`https://www.lalal.ai/api/check/?id=${fileId}`, {
          headers: { 'Authorization': `license ${apiKey}` },
        });
        const result = await checkResp.json();
        if (result.status === 'success') {
          return {
            vocal_url:        result.split.vocals,
            instrumental_url: result.split.accompaniment,
          };
        }
        if (result.status === 'error') throw new Error(result.error);
      }
      throw new Error('Stem splitting timed out');
    });

    // Step 3: Download stems and store in R2
    await step.do('store-stems-in-r2', async () => {
      const [vocalResp, instrResp] = await Promise.all([
        fetch(stemUrls.vocal_url),
        fetch(stemUrls.instrumental_url),
      ]);
      await Promise.all([
        this.env.STEMS_BUCKET.put(`jobs/${jobId}/vocals.mp3`,        vocalResp.body),
        this.env.STEMS_BUCKET.put(`jobs/${jobId}/instrumental.mp3`,  instrResp.body),
      ]);
    });

    // Step 4: Update job status to complete with public R2 URLs
    await step.do('update-status', async () => {
      const base = `https://pub-YOUR_BUCKET_ID.r2.dev/jobs/${jobId}`;
      await this.env.STEMS_BUCKET.put(`jobs/${jobId}/status.json`,
        JSON.stringify({
          status:            'complete',
          vocal_url:         `${base}/vocals.mp3`,
          instrumental_url:  `${base}/instrumental.mp3`,
          completed_at:      new Date().toISOString(),
        })
      );
    });
  }
}
