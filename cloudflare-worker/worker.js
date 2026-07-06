/**
 * OTYA Player — Cloudflare Worker
 *
 * Serves the correct APK from R2 based on the user's device.
 * Version is read live from version.json in R2 — fully automatic.
 *
 * Routes:
 *   /                  → redirect to download page on website
 *   /download          → smart redirect to correct APK for this phone
 *   /download?abi=arm64→ force arm64 APK
 *   /download?abi=arm32→ force arm32 APK
 *   /version           → returns version.json (used by in-app update checker)
 *   /latest            → returns full release info JSON
 *   /apk/arm64         → direct arm64 APK link
 *   /apk/arm32         → direct arm32 APK link
 */

const R2_BASE  = 'https://getotya.download.apk.petersmartlink.com'
const WEBSITE  = 'https://petersmartlink.com/download/otya-player'

const APKS = {
  arm64: R2_BASE + '/app-arm64-v8a-standard-release.apk',
  arm32: R2_BASE + '/app-armeabi-v7a-standard-release.apk',
}

// CORS headers — needed so the Flutter app can call /version
const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
}

// Detect which type of phone the user has from their browser info
function detectAbi(request) {
  const url    = new URL(request.url)
  const param  = url.searchParams.get('abi')
  if (param === 'arm64') return 'arm64'
  if (param === 'arm32') return 'arm32'

  // Client Hints — sent by modern Android Chrome (most reliable)
  const arch = request.headers.get('Sec-CH-UA-Arch') || ''
  if (arch.indexOf('arm64') !== -1 || arch.indexOf('aarch64') !== -1) return 'arm64'
  if (arch.indexOf('arm')   !== -1) return 'arm32'

  // User-Agent fallback
  const ua = (request.headers.get('User-Agent') || '').toLowerCase()
  if (ua.indexOf('arm64')   !== -1) return 'arm64'
  if (ua.indexOf('aarch64') !== -1) return 'arm64'
  if (ua.indexOf('armv8')   !== -1) return 'arm64'
  if (ua.indexOf('armv7')   !== -1) return 'arm32'
  if (ua.indexOf('armeabi') !== -1) return 'arm32'

  // Default — arm64 covers 99%+ of phones made after 2015
  return 'arm64'
}

// Fetch version.json from R2 with a 5-minute edge cache
async function getVersionInfo() {
  try {
    const res = await fetch(R2_BASE + '/version.json', {
      cf: { cacheTtl: 300, cacheEverything: true },
    })
    if (!res.ok) return null
    return await res.json()
  } catch (e) {
    return null
  }
}

export default {
  async fetch(request) {
    const url  = new URL(request.url)
    const path = url.pathname.replace(/\/+$/, '') || '/'

    // OPTIONS preflight for CORS
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS })
    }

    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405 })
    }

    // / → send to website download page
    if (path === '' || path === '/') {
      return Response.redirect(WEBSITE, 302)
    }

    // /version → return version.json (called by the in-app update checker)
    if (path === '/version') {
      const info = await getVersionInfo()
      if (!info) {
        return new Response(
          JSON.stringify({ error: 'version info not available yet' }),
          { status: 503, headers: Object.assign({ 'Content-Type': 'application/json' }, CORS) }
        )
      }
      return new Response(JSON.stringify(info), {
        headers: Object.assign({
          'Content-Type':  'application/json',
          'Cache-Control': 'public, max-age=300',
        }, CORS),
      })
    }

    // /download → detect phone type and redirect to correct APK
    if (path === '/download') {
      const abi = detectAbi(request)
      return Response.redirect(APKS[abi], 302)
    }

    // /apk/arm64 and /apk/arm32 → permanent direct links
    if (path === '/apk/arm64') return Response.redirect(APKS.arm64, 302)
    if (path === '/apk/arm32') return Response.redirect(APKS.arm32, 302)

    // /latest → full release info JSON (useful for websites and bots)
    if (path === '/latest') {
      const info = await getVersionInfo()
      const payload = {
        version:   info ? info.version : 'unknown',
        date:      info ? info.date    : null,
        downloads: {
          auto:  'https://' + url.hostname + '/download',
          arm64: APKS.arm64,
          arm32: APKS.arm32,
        },
      }
      return new Response(JSON.stringify(payload), {
        headers: Object.assign({
          'Content-Type':  'application/json',
          'Cache-Control': 'public, max-age=300',
        }, CORS),
      })
    }

    return new Response('Not found', { status: 404 })
  },
}
