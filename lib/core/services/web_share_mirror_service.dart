import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../services/media_scanner_service.dart';

/// Phone-to-PC browser streaming gateway on port 8085.
/// Serves a full HTML dashboard + /api/media-list + /api/stream with range requests.
class WebShareMirrorService {
  WebShareMirrorService._();
  static final WebShareMirrorService instance = WebShareMirrorService._();

  static const int port      = 8085;
  static const int _chunkSz  = 256 * 1024;

  HttpServer? _server;
  String?     _localIp;

  bool   get isRunning    => _server != null;
  String get localIp      => _localIp ?? '127.0.0.1';
  String get dashboardUrl => 'http://$localIp:$port';

  Future<String> start() async {
    await stop();
    _localIp = await _getLocalIp();
    _server  = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handle,
        onError: (Object e) => debugPrint('[WebMirror] $e'), cancelOnError: false);
    debugPrint('[WebMirror] http://$_localIp:$port');
    return dashboardUrl;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null; _localIp = null;
  }

  Future<void> _handle(HttpRequest req) async {
    req.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    if (req.method == 'OPTIONS') { req.response..statusCode = 200..close(); return; }
    final p = req.uri.path;
    try {
      if (p == '/' || p == '/index.html') await _html(req);
      else if (p == '/api/media-list')    await _mediaList(req);
      else if (p == '/api/stream')        await _stream(req);
      else { req.response..statusCode = 404..write('Not found')..close(); }
    } catch (e) {
      debugPrint('[WebMirror] Handler error: $e');
      try { req.response..statusCode = 500..write('Error')..close(); } catch (_) {}
    }
  }

  Future<void> _html(HttpRequest req) async {
    const html = '''<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OTYA Player — Web Mirror</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{background:#090D16;color:#EEF4FF;font-family:system-ui,sans-serif}
header{background:#0F1626;padding:16px 24px;border-bottom:1px solid #1A2540}
header h1{font-size:20px;font-weight:800;background:linear-gradient(90deg,#00D4FF,#7C3AED);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
#search{width:100%;padding:10px 16px;background:#0F1626;border:1px solid #1A2540;border-radius:10px;color:#EEF4FF;font-size:14px;margin:16px 0;outline:none}
#search:focus{border-color:#00D4FF}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px;padding:0 16px 32px}
.card{background:#0F1626;border:1px solid #1A2540;border-radius:14px;overflow:hidden;cursor:pointer;transition:border-color .2s}
.card:hover{border-color:#00D4FF}.thumb{height:110px;background:#162035;display:flex;align-items:center;justify-content:center;font-size:36px}
.body{padding:12px}.title{font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;margin-bottom:4px}
.meta{font-size:11px;color:#5E7399}.actions{display:flex;gap:8px;margin-top:10px}
.btn{flex:1;padding:7px;border:none;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer}
.s{background:#00D4FF;color:#000}.d{background:#1A2540;color:#EEF4FF}
#modal{display:none;position:fixed;inset:0;background:rgba(0,0,0,.85);align-items:center;justify-content:center;z-index:100}
#modal.open{display:flex}#modal video{max-width:95vw;max-height:90vh;border-radius:12px}
#mc{position:absolute;top:16px;right:20px;background:none;border:none;color:#EEF4FF;font-size:28px;cursor:pointer}
.empty{text-align:center;padding:80px;color:#5E7399}</style></head><body>
<header><h1>⚡ OTYA Player Web Mirror</h1><span id="cnt" style="font-size:12px;color:#5E7399">Loading…</span></header>
<div style="padding:0 16px"><input id="search" type="search" placeholder="Search…" oninput="filter()"></div>
<div id="grid" class="grid"><div class="empty">Scanning library…</div></div>
<div id="modal"><button id="mc" onclick="close2()">✕</button><video id="vp" controls autoplay></video></div>
<script>let all=[];async function load(){try{const r=await fetch('/api/media-list');all=await r.json();document.getElementById('cnt').textContent=all.length+' files';render(all);}catch(e){document.getElementById('grid').innerHTML='<div class="empty">Error loading library.</div>';}}
function render(items){const g=document.getElementById('grid');if(!items.length){g.innerHTML='<div class="empty">No files.</div>';return;}
g.innerHTML=items.map(f=>{const e=encodeURIComponent(f.path);const ic=f.isVideo?'🎬':'🎵';
return`<div class="card"><div class="thumb">${ic}</div><div class="body"><div class="title" title="${f.title}">${f.title}</div><div class="meta">${f.size}</div><div class="actions">${f.isVideo?`<button class="btn s" onclick="stream('${e}')">&#9654; Stream</button>`:''}<button class="btn d" onclick="dl('${e}')">⬇ Download</button></div></div></div>`;}).join('');}
function filter(){const q=document.getElementById('search').value.toLowerCase();render(q?all.filter(f=>f.title.toLowerCase().includes(q)):all);}
function stream(e){document.getElementById('vp').src='/api/stream?path='+e;document.getElementById('modal').classList.add('open');}
function dl(e){const a=document.createElement('a');a.href='/api/stream?path='+e;a.download='';a.click();}
function close2(){const v=document.getElementById('vp');v.pause();v.src='';document.getElementById('modal').classList.remove('open');}
document.getElementById('modal').addEventListener('click',e=>{if(e.target===document.getElementById('modal'))close2();});load();</script></body></html>''';
    req.response..statusCode = 200..headers.contentType = ContentType.html..write(html);
    await req.response.close();
  }

  Future<void> _mediaList(HttpRequest req) async {
    try {
      final items = await MediaScannerService.instance.scanAll();
      // Sort by date added descending so newest files appear first in the browser.
      final sorted = [...items]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      final json   = sorted.map((i) => {
        'title':    i.title,
        'path':     i.filePath,
        'size':     i.formattedSize,
        'isVideo':  i.isVideo,
        'duration': i.duration?.inSeconds ?? 0,
      }).toList();
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(json));
    } catch (e) {
      req.response
        ..statusCode = 500
        ..write(jsonEncode({'error': '$e'}));
    }
    await req.response.close();
  }

  Future<void> _stream(HttpRequest req) async {
    final enc  = req.uri.queryParameters['path'] ?? '';
    if (enc.isEmpty) { req.response..statusCode = 400..write('Missing path')..close(); return; }
    // Sanitise path — prevent directory traversal attacks.
    final decoded = Uri.decodeComponent(enc);
    if (decoded.contains('..') || !decoded.startsWith('/storage/')) {
      req.response..statusCode = 403..write('Forbidden')..close();
      return;
    }
    final file = File(decoded);
    if (!await file.exists()) { req.response..statusCode = 404..write('Not found')..close(); return; }
    final len  = await file.length();
    final mime = _mime(file.path);
    final rh   = req.headers.value(HttpHeaders.rangeHeader);
    int start = 0, end = len - 1;
    bool partial = false;
    if (rh != null && rh.startsWith('bytes=')) {
      partial = true;
      final p = rh.substring(6).split('-');
      start = int.tryParse(p[0]) ?? 0;
      end   = (p.length > 1 && p[1].isNotEmpty) ? (int.tryParse(p[1]) ?? (len-1)) : (len-1);
      end   = end.clamp(0, len-1); start = start.clamp(0, end);
    }
    final cl = end - start + 1;
    req.response
      ..statusCode = partial ? 206 : 200
      ..headers.contentType = ContentType.parse(mime)
      ..headers.set(HttpHeaders.contentLengthHeader, cl)
      ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    if (partial) req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$len');
    if (req.method == 'HEAD') { await req.response.close(); return; }
    RandomAccessFile? raf;
    try {
      raf = await file.open(); await raf.setPosition(start);
      int rem = cl;
      while (rem > 0) {
        final n = rem < _chunkSz ? rem : _chunkSz;
        final c = await raf.read(n);
        if (c.isEmpty) break;
        req.response.add(c); rem -= c.length;
        await Future<void>.delayed(Duration.zero);
      }
    } finally { await raf?.close(); await req.response.close(); }
  }

  Future<String> _getLocalIp() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final i in ifaces) for (final a in i.addresses)
        if (a.address.startsWith('192.168.') || a.address.startsWith('10.')) return a.address;
      for (final i in ifaces) for (final a in i.addresses) if (!a.isLoopback) return a.address;
    } catch (_) {}
    return '127.0.0.1';
  }

  String _mime(String p) {
    const m = {'mp4':'video/mp4','mkv':'video/x-matroska','avi':'video/x-msvideo',
      'mov':'video/quicktime','webm':'video/webm','mp3':'audio/mpeg','aac':'audio/aac',
      'flac':'audio/flac','wav':'audio/wav','ogg':'audio/ogg','m4a':'audio/mp4'};
    return m[p.split('.').last.toLowerCase()] ?? 'application/octet-stream';
  }
}
