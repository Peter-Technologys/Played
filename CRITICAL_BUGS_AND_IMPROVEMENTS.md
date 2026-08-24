# OTYA Player - Critical Issues & Improvement Roadmap

**Current Status**: v1.5.0+8 (Dart 94.3%, Kotlin 4%, Shell 1.7%)
**Priority**: 🔴 CRITICAL - Multiple stability, security, and UX issues blocking production

---

## 🔴 TIER 1: CRITICAL BUGS (Blocking Production)

### Playback & Audio Issues

#### 1. **Media Kit Player Race Condition** [BLOCKING]
- **Impact**: Audio/video playback fails randomly, especially on slower devices
- **Root Cause**: Two independent Player instances (audio_service + media_kit) out of sync
- **Files**: 
  - `lib/core/services/audio_handler.dart` (Line 25)
  - `lib/features/player/presentation/audio_player_screen.dart` (Line 71)
- **Fix Required**:
```dart
// BEFORE: Two separate players
final Player _player = Player(...);  // In AudioPlayerNotifier
Player? _player;  // In OtyaAudioHandler

// AFTER: Single unified player
// Use media_kit Player directly, attach to audio_service via handler
// No duplication, single state machine
```
- **Estimated Fix Time**: 4 hours
- **Test Cases**: 
  - [ ] Play 10 songs consecutively, verify no stuttering
  - [ ] Lock screen playback persists 5 minutes
  - [ ] Bluetooth controls work without delay
  - [ ] Switch audio→video→audio without crashes

---

#### 2. **Stale Loading Flag Deadlock** [BLOCKING]
- **Impact**: Player hangs if network is slow; retry button does nothing
- **File**: `lib/features/player/presentation/audio_player_screen.dart` (Lines 189-194)
- **Current Code**:
```dart
if (_loading) {
  debugPrint('[AudioPlayer] _loadCurrent: resetting stale _loading flag.');
  _loading = false;  // ← HIDES THE REAL ERROR
}
_loading = true;
```
- **Fix**: Replace with AsyncQueue or Promise-based loading
- **Estimated Fix Time**: 3 hours

---

#### 3. **Playback Coordinator Timeout Hang** [CRITICAL]
- **Impact**: Switching audio→video freezes the app for 30+ seconds if network is interrupted
- **File**: `lib/core/services/playback_coordinator.dart` (Line 26)
- **Current Code**:
```dart
try { await _activePlayer!.pause(); } catch (_) {}  // ← NO TIMEOUT!
```
- **Fix Required**:
```dart
try {
  await _activePlayer!.pause().timeout(
    const Duration(seconds: 2),
    onTimeout: () => throw TimeoutException('Pause timeout'),
  );
} catch (e) {
  debugPrint('[PlaybackCoordinator] Pause failed: $e, forcing registration');
  // Continue anyway — don't block new player
}
```
- **Estimated Fix Time**: 1 hour

---

### Database & Backend Issues

#### 4. **Database ID Collision - Auth vs Store** [CRITICAL]
- **Impact**: User playlists & sync data writes to SAME database as download analytics, causing race conditions
- **Files**: 
  - `auth-worker/wrangler.toml` (Line 12)
  - Main `wrangler.toml` (Line 33)
- **Current**: Both use `ab157fc6-2cbb-4d46-9789-2e4392e16aea`
- **Fix**: Create separate auth database
```toml
# auth-worker/wrangler.toml
[[d1_databases]]
binding       = "AUTH_DB"
database_name = "otya-auth-db-production"
database_id   = "YOUR-NEW-UNIQUE-AUTH-DB-ID"  # ← MUST BE DIFFERENT
```
- **Estimated Fix Time**: 30 min
- **Deploy Step**: Create new D1 DB in Cloudflare → migrate secrets → test

---

#### 5. **Missing Error Handling - Version.json Fallback** [CRITICAL]
- **Impact**: If R2 version.json is deleted, ALL users can't download APK
- **File**: `src/index.js` (Line 227-229)
- **Fix Required**:
```javascript
const info = await getVersionInfo(env)
if (!info) {
  // Fallback: return last-known-good version from KV
  const fallback = await env.KV.get('version:fallback', 'json')
  if (!fallback) {
    ctx.waitUntil(sendErrorAlert(env, 'CRITICAL: No version info', 
      'version.json missing AND no fallback in KV. Users blocked.'))
    return new Response(JSON.stringify({ 
      error: 'APK not available. Maintenance in progress.',
      retryAfter: 300 
    }), { status: 503, headers: { 'Retry-After': '300', ...CORS } })
  }
  return jsonResponse(fallback)
}
```
- **Estimated Fix Time**: 1 hour

---

### Security Issues

#### 6. **No Input Validation - Path Traversal Risk** [CRITICAL]
- **Files**: `lib/core/services/media_kit_engine.dart`, `lib/features/player/*`
- **Vulnerability**: 
```dart
// UNSAFE: User can pass paths like ../../../etc/passwd
await _player!.open(Media(item.filePath), play: false);
```
- **Fix**:
```dart
// SAFE: Validate path is within app directories only
bool isPathSafe(String path) {
  final file = File(path);
  final resolved = file.resolveSymbolicLinksSync();
  
  // Only allow paths in these locations:
  final allowedDirs = [
    Directory.systemTemp.path,
    (await getApplicationDocumentsDirectory()).path,
    (await getExternalStorageDirectory())?.path,
    '/sdcard/Download',
    '/sdcard/Music',
  ];
  
  for (final dir in allowedDirs) {
    if (resolved.startsWith(dir)) return true;
  }
  return false;
}

// Before opening:
if (!isPathSafe(item.filePath)) {
  throw SecurityException('Invalid file path: ${item.filePath}');
}
```
- **Estimated Fix Time**: 2 hours

---

#### 7. **Vault XOR Obfuscation is NOT Encryption** [SECURITY]
- **Current Implementation**: `lib/core/services/vault_service.dart`
- **Problem**: XOR first 512 bytes only obfuscates, doesn't encrypt. Easy to crack.
- **GDPR/Privacy Risk**: User data not properly protected
- **Fix**: Use proper AES-256-GCM encryption
```dart
import 'package:encrypt/encrypt.dart' as encrypt;

class VaultService {
  late encrypt.Key _key;
  late encrypt.IV _iv;
  
  Future<void> encryptVault(File file) async {
    final plaintext = await file.readAsBytes();
    final cipher = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.gcm));
    final encrypted = cipher.encryptBytes(plaintext, iv: _iv);
    await file.writeAsBytes(encrypted.bytes);
  }
}
```
- **Estimated Fix Time**: 4 hours
- **Breaking Change**: Existing vault files will need migration

---

---

## 🟠 TIER 2: MAJOR STABILITY ISSUES (High Impact)

### Initialization & Lifecycle

#### 8. **Cold-Start Crash on Devices < Android 10**
- **File**: `lib/main.dart` (Line 42)
- **Issue**: `MediaKit.ensureInitialized()` called BEFORE checking device API level
- **Fix**:
```dart
// Check API level first
final deviceInfo = DeviceInfoPlugin();
final androidInfo = await deviceInfo.androidInfo;
if (androidInfo.version.sdkInt < 29) {
  debugPrint('[WARNING] Device API < 29, MediaKit may not work');
  // Fallback to platform channel playback
}
MediaKit.ensureInitialized();
```
- **Estimated Fix Time**: 2 hours

---

#### 9. **Background Service Killed on Memory Pressure**
- **File**: `lib/main.dart` (Line 183-187, `_initBackground`)
- **Issue**: Services initialized in parallel, not sequenced. If one fails, others may not start.
- **Current**:
```dart
await Future.wait([
  _initNotifications(),
  _initWorkManager(),
  StorageFolderService.instance.ensureCreated(),  // No error handling!
]);
```
- **Fix**: Sequence critical services, allow non-critical to fail gracefully
```dart
// Critical services — must succeed
try {
  await _initNotifications();
  await _initWorkManager();
} catch (e) {
  debugPrint('[CRITICAL] Service init failed: $e');
  // Show user error dialog
}

// Non-critical — fail silently
unawaited(
  StorageFolderService.instance.ensureCreated()
    .catchError((e) => debugPrint('[Storage] Init failed: $e'))
);
```
- **Estimated Fix Time**: 2 hours

---

### Stream & Memory Leaks

#### 10. **Stacked Stream Subscriptions**
- **File**: `lib/features/player/presentation/audio_player_screen.dart` (Lines 107-155)
- **Issue**: `_attachStreams()` called multiple times without unsubscribing old streams
- **Current Code**:
```dart
void _attachStreams() {
  _playingSub = _player.stream.playing.listen(...);  // ← No cancel() first!
  _bufferingSub = _player.stream.buffering.listen(...);
  // ... more subscriptions
}
```
- **Fix**:
```dart
void _attachStreams() {
  // Cancel any existing subscriptions
  _playingSub?.cancel();
  _bufferingSub?.cancel();
  _positionSub?.cancel();
  _durationSub?.cancel();
  _completedSub?.cancel();
  
  // Now attach fresh
  _playingSub = _player.stream.playing.listen(...);
  // ... more subscriptions
}
```
- **Estimated Fix Time**: 1 hour
- **Memory Impact**: 5-10 MB leak per re-attach

---

#### 11. **Provider Lifecycle Mismatch**
- **File**: `lib/features/player/presentation/audio_player_screen.dart` (Line 361-370)
- **Issue**: `audioPlayerProvider` is a StateNotifierProvider that creates NEW notifier on every watch
- **Current**:
```dart
final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  (ref) {
    final notifier = AudioPlayerNotifier();  // ← NEW instance EVERY TIME
    notifier._container = ref.container;
    notifier.init();
    return notifier;
  },
);
```
- **Fix**: Use `.family` or ensure single instance per logical screen
```dart
final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  (ref) {
    final notifier = AudioPlayerNotifier();
    ref.onDispose(() {
      debugPrint('[AudioPlayer] Disposing notifier');
      notifier.dispose();  // Explicit cleanup
    });
    notifier._container = ref.container;
    notifier.init();
    return notifier;
  },
);
```
- **Estimated Fix Time**: 2 hours

---

---

## 🟡 TIER 3: PERFORMANCE & OPTIMIZATION

### UI/UX Responsiveness

#### 12. **Album Art Loading Blocks Main Thread**
- **File**: `lib/features/player/presentation/audio_player_screen.dart` (Lines 809-814, `_AlbumArt._resolve`)
- **Issue**: `AlbumArtService.resolve()` is synchronous, blocks UI for 500ms-2s
- **Current**:
```dart
Future<void> _resolve() async {
  if (mounted) setState(() => _loading = true);
  final path = await AlbumArtService.instance.resolve(widget.albumArtPath);
  // ↑ This blocks UI if the service is doing file I/O
  if (mounted) setState(() { _resolvedPath = path; _loading = false; });
}
```
- **Fix**: Use compute() to run in background isolate
```dart
Future<void> _resolve() async {
  if (mounted) setState(() => _loading = true);
  try {
    final path = await compute(
      AlbumArtService.instance.resolveIsolate,
      widget.albumArtPath,
      debugLabel: 'AlbumArtResolve',
    );
    if (mounted) setState(() { _resolvedPath = path; _loading = false; });
  } catch (e) {
    debugPrint('[AlbumArt] Resolve error: $e');
    if (mounted) setState(() { _loading = false; });
  }
}
```
- **Estimated Fix Time**: 2 hours
- **UX Impact**: Smooth UI, no frozen playback screen

---

#### 13. **Video Seek Bar 60fps Rebuild Issue**
- **File**: `android/app/src/main/kotlin/com/otyaplayer/app/MainActivity.kt` (CHANGELOG notes this was fixed)
- **Verify**: Check if position updates still cause 60 rebuilds/second
- **Current Status**: Listed as fixed in v1.3.3, but verify it's still working
- **Test**: Record FPS profile while seeking in video player
- **If Not Fixed**:
```dart
// Add throttle to position stream
_positionSub = _player.stream.position
  .throttle(const Duration(milliseconds: 500))
  .listen((p) {
    if (!mounted) return;
    state = state.copyWith(position: p);
  });
```
- **Estimated Fix Time**: 1 hour if needed

---

### Database & Caching

#### 14. **No Database Indices on Search Queries**
- **File**: `lib/features/my_space/*` (search implementation)
- **Issue**: Searching 10,000+ media files scans entire table, takes 2-5 seconds
- **Fix**: Add indices to Hive
```dart
// In PlayedDatabase.init()
final mediaBox = Hive.box<MediaItem>('media');
// Create indices on frequently searched fields
// Note: Hive doesn't support indices natively, use manual optimization:

// Option A: Cache filtered results
final Map<String, List<MediaItem>> _searchCache = {};

List<MediaItem> search(String query) {
  if (_searchCache.containsKey(query)) {
    return _searchCache[query]!;
  }
  
  final results = mediaBox.values
    .where((m) => m.title.toLowerCase().contains(query.toLowerCase()))
    .toList();
  
  _searchCache[query] = results;
  return results;
}

// Option B: Use sqlite instead of Hive for better indexing
// (larger refactor, but worth it for scale)
```
- **Estimated Fix Time**: 2-3 hours

---

#### 15. **No Cache Invalidation on Library Refresh**
- **File**: `lib/features/my_space/providers/*`
- **Issue**: Stale media items shown after files added/deleted externally
- **Fix**:
```dart
Future<void> refreshLibrary() async {
  // 1. Scan file system
  final newItems = await scanFileSystem();
  
  // 2. Invalidate cached state
  mediaLibraryProvider.invalidate();
  searchResultProvider.invalidate();
  playlistsProvider.invalidate();
  
  // 3. Refresh UI
  ref.refresh(mediaLibraryProvider);
}
```
- **Estimated Fix Time**: 1 hour

---

### Battery & Network

#### 16. **No Network State Listening**
- **Issue**: App tries to download/sync when offline, wastes battery
- **Fix**:
```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkAwareService {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _subscription;
  
  void init() {
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        pauseAllNetworkOperations();
      } else {
        resumeQueuedOperations();
      }
    });
  }
}
```
- **Estimated Fix Time**: 2 hours

---

---

## 🎨 TIER 4: UI/UX IMPROVEMENTS (Why It Looks "Old")

### Thumbnail & Media Display

#### 17. **Thumbnail Generation Issues** [HIGH PRIORITY]
- **Current Implementation**: `lib/core/services/album_art_service.dart`
- **Problems**:
  1. **No Placeholder Gradients**: Blank white squares while loading
  2. **Low Resolution**: Extracting from MediaStore at 128x128 (should be 256x512)
  3. **No Caching**: Regenerate thumbnail every app session
  4. **No Shadow/Depth**: Flat appearance, no visual hierarchy
  5. **No Animation**: Instant appearance feels jarring

#### **Fix 1: Better Placeholders**
```dart
// BEFORE: Plain white box
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppColors.accent.withValues(alpha: 0.15),
        AppColors.accentViolet.withValues(alpha: 0.25),
      ],
    ),
  ),
)

// AFTER: Animated gradient + music note icon
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppColors.accent.withValues(alpha: 0.15),
        AppColors.accentViolet.withValues(alpha: 0.25),
      ],
    ),
  ),
  child: Center(
    child: AnimatedOpacity(
      opacity: isLoading ? 0.7 : 0.4,
      duration: const Duration(seconds: 1),
      child: Icon(
        Icons.music_note_rounded,
        color: AppColors.accent,
        size: 60,
      ),
    ),
  ),
)
```
- **Estimated Fix Time**: 1 hour

#### **Fix 2: Higher Resolution Thumbnails**
```dart
Future<Uint8List?> getAlbumArt(int albumId) async {
  try {
    // Request higher resolution (512x512 instead of 128x128)
    return await methodChannel.invokeMethod<Uint8List>(
      'getAlbumArt',
      {'albumId': albumId, 'size': 512},  // ← LARGER SIZE
    );
  } catch (e) {
    debugPrint('[AlbumArt] Error: $e');
    return null;
  }
}
```

#### **Fix 3: Persistent Thumbnail Cache**
```dart
class ThumbnailCache {
  static final _cache = <int, Uint8List>{};
  static const _maxSize = 100;  // Cache top 100 albums
  
  static Future<Uint8List?> get(int albumId) async {
    // Check memory cache
    if (_cache.containsKey(albumId)) return _cache[albumId];
    
    // Check disk cache
    final file = File('${(await getTemporaryDirectory()).path}/thumb_$albumId.jpg');
    if (await file.exists()) {
      final data = await file.readAsBytes();
      _cache[albumId] = data;
      return data;
    }
    
    // Fetch from MediaStore
    final data = await _getFromMediaStore(albumId);
    if (data != null) {
      _cache[albumId] = data;
      await file.writeAsBytes(data);  // Save to disk
    }
    return data;
  }
}
```
- **Estimated Fix Time**: 3 hours

#### **Fix 4: Add Visual Depth & Shadow**
```dart
// BEFORE: Flat image
ClipRRect(
  borderRadius: BorderRadius.circular(28),
  child: Image.file(File(_resolvedPath!), fit: BoxFit.cover),
)

// AFTER: Depth with shadow + subtle glow
ClipRRect(
  borderRadius: BorderRadius.circular(28),
  child: Stack(
    children: [
      // Inner shadow for depth
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              inset: true,
            ),
          ],
        ),
      ),
      // Image
      Image.file(File(_resolvedPath!), fit: BoxFit.cover),
      // Glow overlay (only when playing)
      if (widget.isPlaying)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
    ],
  ),
)
```
- **Estimated Fix Time**: 2 hours

#### **Fix 5: Smooth Load Animation**
```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  transitionBuilder: (child, animation) {
    return ScaleTransition(scale: animation, child: child);
  },
  child: showArt
    ? Image.file(
        File(_resolvedPath!),
        fit: BoxFit.cover,
        key: ValueKey(_resolvedPath),
      )
    : buildPlaceholder(),
)
```
- **Estimated Fix Time**: 1 hour

---

### Modern Design Updates

#### 18. **Update Color Palette** [VISUAL MODERNIZATION]
- **Current**: Cyan (#00E5FF) is very 2019. Feels dated.
- **Modern**: Gradient from Cyan → Purple or use current teal but with better contrast
- **File**: `lib/app/theme/app_colors.dart`

**Before**:
```dart
static const Color accent = Color(0xFF00E5FF);  // Cyan
static const Color accentViolet = Color(0xFFB700FF);  // Purple
```

**After** (Updated Modern Palette):
```dart
// Option 1: Gradient Cyan → Teal (More modern)
static const Color accentPrimary = Color(0xFF00D9FF);     // Bright cyan
static const Color accentSecondary = Color(0xFF0098D4);   // Deeper teal
static const Color accentViolet = Color(0xFF6E5AFF);      // Modern purple

// Option 2: Add dark mode variants
static const Color accentLight = Color(0xFF00E5FF);
static const Color accentDark = Color(0xFF0088CC);
```

- **Update Required**: Change in 15+ files (colors, gradients, shadows)
- **Estimated Fix Time**: 4 hours

---

#### 19. **Add Micro-Interactions**
- **Current**: Buttons feel static, no feedback
- **Modern**: Add haptic feedback + scale animations

```dart
GestureDetector(
  onTap: () {
    HapticFeedback.mediumImpact();  // ← Already in code
    ref.read(audioPlayerProvider.notifier).togglePlay();
  },
  child: AnimatedScale(
    scale: isPressed ? 0.95 : 1.0,  // ← ADD THIS
    duration: const Duration(milliseconds: 100),
    child: playButton,
  ),
)
```

- **Estimated Fix Time**: 2 hours

---

#### 20. **Modernize Typography**
- **Current**: Using 'Inter' font, but sizes are inconsistent
- **Fix**: Define proper type scale
```dart
// lib/app/theme/app_typography.dart
class AppTypography {
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );
  
  // ... more scales
}
```
- **Estimated Fix Time**: 3 hours

---

---

## 🔐 TIER 5: SECURITY HARDENING

### Data Protection

#### 21. **Implement Proper Encryption**
- **Current**: XOR obfuscation (BROKEN)
- **Fix**: AES-256-GCM
- **Files to update**: `lib/core/services/vault_service.dart`
- **Estimated Fix Time**: 5 hours

#### 22. **Add SSL Pinning**
- **Current**: No protection against MITM attacks
- **Fix**: Pin certificate for Cloudflare API
```dart
// Add to Dio interceptors
import 'package:dio/dio.dart';

final dio = Dio()
  ..interceptors.add(
    CertificatePinningInterceptor([
      'sha256/...your-cloudflare-cert-hash...',
    ]),
  );
```
- **Estimated Fix Time**: 2 hours

#### 23. **Secure Shared Preferences**
- **Current**: Settings stored in plain text
- **Fix**: Use `flutter_secure_storage`
```dart
// BEFORE
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('onboarding_done', true);

// AFTER
final secureStorage = const FlutterSecureStorage();
await secureStorage.write(key: 'onboarding_done', value: 'true');
```
- **Estimated Fix Time**: 2 hours

---

---

## 📊 PRIORITY TIMELINE & ESTIMATE

### Phase 1: Critical (Week 1) - 25-30 hours
1. ✅ Fix Playback Coordinator timeout (1h)
2. ✅ Fix Loading Flag deadlock (3h)
3. ✅ Separate Auth DB (0.5h)
4. ✅ Media Kit Player consolidation (4h)
5. ✅ Add version.json fallback (1h)
6. ✅ Cold-start API check (2h)
7. ✅ Background service sequencing (2h)
8. ✅ Stream subscription cleanup (1h)

**Result**: Stable playback, no crashes on slow devices

---

### Phase 2: Stability (Week 2) - 20-25 hours
1. ✅ Thumbnail caching & resolution (3h)
2. ✅ Album art async loading (2h)
3. ✅ Database indices/search optimization (2-3h)
4. ✅ Path validation security (2h)
5. ✅ Network state listening (2h)
6. ✅ Vault encryption migration (5h)

**Result**: Smooth UI, better search, improved security

---

### Phase 3: UX/Polish (Week 3) - 15-20 hours
1. ✅ Thumbnail placeholders + animations (3h)
2. ✅ Color palette update (4h)
3. ✅ Typography system (3h)
4. ✅ Micro-interactions (2h)
5. ✅ SSL pinning (2h)
6. ✅ Secure preferences (2h)

**Result**: Modern, polished UI; better security

---

## 🎯 TESTING CHECKLIST

- [ ] Playback doesn't stutter on Pixel 3 (low-end device)
- [ ] Album art loads without blocking UI
- [ ] Search 10,000 items in <1 second
- [ ] Battery drain < 5% per hour of playback
- [ ] App boots in <3 seconds
- [ ] No memory leaks over 1 hour session
- [ ] Offline sync works without crashes
- [ ] GDPR compliance: user data encrypted
- [ ] 60fps in UI during playback
- [ ] Lock screen controls responsive (<200ms delay)

---

## 📦 BACKEND (Otya-Store) FIXES NEEDED

### Critical
- [ ] Separate auth DB from store DB
- [ ] Add version.json fallback
- [ ] Rate limiting increase to 30/min
- [ ] Error response validation

### Stability
- [ ] Add database migrations
- [ ] Backup strategy
- [ ] Index on `devices.last_seen_at`
- [ ] FK constraints on ratings/feedback

### Performance
- [ ] KV cache for auth tokens
- [ ] Compress APK response
- [ ] CDN caching headers

---

## 🚀 DEPLOYMENT STRATEGY

1. **Phase 1**: Deploy to internal testing, fix crashes
2. **Phase 2**: Beta release to 10% of users, monitor crashes
3. **Phase 3**: Full release with new UI

---

**Total Estimated Effort**: 60-75 hours = 1.5-2 weeks of full-time work

**Recommended**: Parallelize Phase 1 across 2-3 developers while others start Phase 2

Would you like me to start implementing these fixes in order of priority?
