/**
 * OTYA Player — Cloudflare Worker (small-paper-5a45)
 *
 * Serves APKs from a PRIVATE R2 bucket via R2 binding.
 * The bucket is never publicly accessible — all downloads go through this Worker.
 *
 * Routes:
 *   /           → redirect to website download page
 *   /version    → raw version.json from R2 (used by in-app update checker)
 *   /latest     → structured JSON with version, changelog, download URLs
 *   /download   → auto-detect ABI, stream correct APK from R2
 *   /apk/arm64  → stream arm64 APK directly from R2
 *   /apk/arm32  → stream arm32 APK directly from R2
 */

const WEBSITE = 'https://petersmartlink.com/download/otya-player'

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
}

function detectAbi(request) {
  const url   = new URL(request.url)
  const param = url.searchParams.get('abi')
  if (param === 'arm64') return 'arm64'
  if (param === 'arm32') return 'arm32'

  // Client Hints — sent by modern Android Chrome (most reliable)
  const arch = request.headers.get('Sec-CH-UA-Arch') || ''
  if (arch.includes('arm64') || arch.includes('aarch64')) return 'arm64'
  if (arch.includes('arm')) return 'arm32'

  // User-Agent fallback
  const ua = (request.headers.get('User-Agent') || '').toLowerCase()
  if (ua.includes('arm64') || ua.includes('aarch64') || ua.includes('armv8')) return 'arm64'
  if (ua.includes('armv7') || ua.includes('armeabi')) return 'arm32'

  return 'arm64' // safe default — covers 99%+ of phones made after 2015
}

// Read version.json from R2 via binding (no public access needed)
async function getVersionInfo(env) {
  try {
    const obj = await env.R2.get('version.json')
    if (!obj) return null
    return await obj.json()
  } catch {
    return null
  }
}

// Build the R2 object key for an APK
function buildApkKey(info, abi) {
  if (!info || !info.tag) return null
  const filename = abi === 'arm64'
    ? (info.arm64 || `otya-player-${info.tag}-arm64.apk`)
    : (info.arm32 || `otya-player-${info.tag}-arm32.apk`)
  return `releases/${info.tag}/${filename}`
}

// Stream an APK from R2 directly to the client
async function serveApk(env, key) {
  const obj = await env.R2.get(key)
  if (!obj) {
    return new Response(`APK not found: ${key}`, { status: 404 })
  }
  const headers = new Headers()
  obj.writeHttpMetadata(headers)
  headers.set('etag', obj.httpEtag)
  headers.set('Content-Type', 'application/vnd.android.package-archive')
  headers.set('Content-Disposition', `attachment; filename="${key.split('/').pop()}"`)
  headers.set('Cache-Control', 'public, max-age=300')
  // Allow Flutter app to read response
  Object.entries(CORS).forEach(([k, v]) => headers.set(k, v))
  return new Response(obj.body, { headers })
}

export default {
  async fetch(request, env) {
    const url  = new URL(request.url)
    const path = url.pathname.replace(/\/+$/, '') || '/'

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS })
    }
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405 })
    }

    // / → website
    if (path === '' || path === '/') {
      return Response.redirect(WEBSITE, 302)
    }

    // /version → raw version.json
    if (path === '/version') {
      const info = await getVersionInfo(env)
      if (!info) {
        return new Response(
          JSON.stringify({ error: 'version info not available yet' }),
          { status: 503, headers: { 'Content-Type': 'application/json', ...CORS } }
        )
      }
      return new Response(JSON.stringify(info), {
        headers: { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=300', ...CORS },
      })
    }

    // /latest → structured release info
    if (path === '/latest') {
      const info = await getVersionInfo(env)
      const host = url.hostname
      const payload = {
        version:     info?.version     ?? 'unknown',
        versionCode: info?.versionCode ?? 0,
        tag:         info?.tag         ?? null,
        date:        info?.date        ?? null,
        changelog:   info?.changelog   ?? '',
        downloads: {
          auto:  `https://${host}/download`,
          arm64: `https://${host}/apk/arm64`,
          arm32: `https://${host}/apk/arm32`,
        },
      }
      return new Response(JSON.stringify(payload), {
        headers: { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=300', ...CORS },
      })
    }

    // /download → auto-detect ABI and stream APK
    if (path === '/download') {
      const abi  = detectAbi(request)
      const info = await getVersionInfo(env)
      if (!info) {
        return new Response(JSON.stringify({ error: 'version info not available' }),
          { status: 503, headers: { 'Content-Type': 'application/json' } })
      }
      const key = buildApkKey(info, abi)
      if (!key) return new Response('Could not determine APK path', { status: 500 })
      return serveApk(env, key)
    }

    // /apk/arm64 and /apk/arm32 → stream specific APK
    if (path === '/apk/arm64' || path === '/apk/arm32') {
      const abi  = path === '/apk/arm64' ? 'arm64' : 'arm32'
      const info = await getVersionInfo(env)
      if (!info) {
        return new Response(JSON.stringify({ error: 'version info not available' }),
          { status: 503, headers: { 'Content-Type': 'application/json' } })
      }
      const key = buildApkKey(info, abi)
      if (!key) return new Response('Could not determine APK path', { status: 500 })
      return serveApk(env, key)
    }

    return new Response('Not found', { status: 404 })
  },
}
