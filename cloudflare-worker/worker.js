/**
 * OTYA Player — Cloudflare Worker
 *
 * Serves the correct APK from R2 based on the user's device.
 * Version is read live from version.json in R2 — fully automatic.
 *
 * Routes:
 *   /                   → redirect to download page on website
 *   /download           → smart redirect to correct APK for this phone
 *   /download?abi=arm64 → force arm64 APK
 *   /download?abi=arm32 → force arm32 APK
 *   /version            → returns version.json (used by in-app update checker)
 *   /latest             → returns full release info JSON
 *   /apk/arm64          → direct arm64 APK link
 *   /apk/arm32          → direct arm32 APK link
 */

// Public R2 bucket URL — this is the custom domain on your R2 bucket
const R2_BASE = 'https://getotya.petersmartlink.com/r2'
const WEBSITE = 'https://petersmartlink.com/download/otya-player'

// CORS headers — needed so the Flutter app can call /version
const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
}

// Detect which ABI the user's phone needs
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

// Fetch version.json from R2 root with a 5-minute edge cache
async function getVersionInfo() {
  try {
    const res = await fetch(R2_BASE + '/version.json', {
      cf: { cacheTtl: 300, cacheEverything: true },
    })
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}

// Build APK URLs from version info (versioned folder structure)
function getApkUrls(info) {
  if (!info || !info.tag) {
    // Fallback to latest symlink if version info unavailable
    return {
      arm64: R2_BASE + '/latest/otya-player-latest-arm64.apk',
      arm32: R2_BASE + '/latest/otya-player-latest-arm32.apk',
    }
  }
  const tag = info.tag
  return {
    arm64: `${R2_BASE}/releases/${tag}/otya-player-${tag}-arm64.apk`,
    arm32: `${R2_BASE}/releases/${tag}/otya-player-${tag}-arm32.apk`,
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
          { status: 503, headers: { 'Content-Type': 'application/json', ...CORS } }
        )
      }
      return new Response(JSON.stringify(info), {
        headers: {
          'Content-Type':  'application/json',
          'Cache-Control': 'public, max-age=300',
          ...CORS,
        },
      })
    }

    // /download → detect phone type and redirect to correct APK
    if (path === '/download') {
      const info = await getVersionInfo()
      const apks = getApkUrls(info)
      const abi  = detectAbi(request)
      return Response.redirect(apks[abi], 302)
    }

    // /apk/arm64 and /apk/arm32 → direct links
    if (path === '/apk/arm64' || path === '/apk/arm32') {
      const info = await getVersionInfo()
      const apks = getApkUrls(info)
      const abi  = path === '/apk/arm64' ? 'arm64' : 'arm32'
      return Response.redirect(apks[abi], 302)
    }

    // /latest → full release info JSON
    if (path === '/latest') {
      const info = await getVersionInfo()
      const apks = getApkUrls(info)
      const payload = {
        version:   info?.version   ?? 'unknown',
        versionCode: info?.versionCode ?? 0,
        date:      info?.date      ?? null,
        changelog: info?.changelog ?? '',
        tag:       info?.tag       ?? null,
        downloads: {
          auto:  'https://' + url.hostname + '/download',
          arm64: apks.arm64,
          arm32: apks.arm32,
        },
      }
      return new Response(JSON.stringify(payload), {
        headers: {
          'Content-Type':  'application/json',
          'Cache-Control': 'public, max-age=300',
          ...CORS,
        },
      })
    }

    return new Response('Not found', { status: 404 })
  },
}
