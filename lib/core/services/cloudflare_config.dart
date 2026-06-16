/// Cloudflare integration constants for PLAYED.
///
/// HOW TO SET UP:
/// 1. Create a Cloudflare account at https://dash.cloudflare.com
/// 2. Create an R2 bucket named 'played-stems'
/// 3. Deploy the Worker from /cloudflare/workers/stem_splitter.js
/// 4. Deploy the Workflow from /cloudflare/workflows/stem_workflow.js
/// 5. Replace the placeholder URLs below with your real Worker URLs.
///
/// ENVIRONMENT VARIABLES (set in Cloudflare Dashboard → Workers → Settings):
///   SPLEETER_API_KEY  — your stem-splitting API key (e.g. from lalal.ai)
///   R2_BUCKET         — bound R2 bucket (set in wrangler.toml)
abstract class CloudflareConfig {
  // ── Worker endpoints ────────────────────────────────────────────────
  // Replace with your actual Worker subdomain after deployment.
  // Format: https://<worker-name>.<your-subdomain>.workers.dev

  /// Stem-splitting Workflow trigger endpoint.
  static const String stemWorkerUrl =
      'https://played-stem-splitter.stream.petersmartlink.com';

  /// FFmpeg operations Worker endpoint (extract audio, trim for WhatsApp).
  static const String ffmpegWorkerUrl =
      'https://played-ffmpeg.stream.petersmartlink.com';

  /// R2 public bucket URL for downloading processed stems.
  /// Enable public access in R2 bucket settings → Public Access.
  static const String r2PublicUrl =
      'https://pub-2189e34e5b9a4ec1bd7c5a0eec200655.r2.dev';

  // ── Auth ────────────────────────────────────────────────────────────
  /// Shared secret between the app and your Worker.
  /// Set this as a Worker secret: wrangler secret put APP_SECRET
  /// Then put the same value here (or load from --dart-define in CI).
  static const String workerSecret =
      String.fromEnvironment('CF_WORKER_SECRET', defaultValue: 'dev-secret');

  // ── Timeouts ────────────────────────────────────────────────────────
  static const Duration uploadTimeout   = Duration(minutes: 3);
  static const Duration pollInterval    = Duration(seconds: 4);
  static const Duration jobMaxWait      = Duration(minutes: 10);
}
