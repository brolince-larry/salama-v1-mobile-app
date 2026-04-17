// lib/services/smart_poll.dart
//
// SmartPoller — a single reusable polling primitive that:
//
//   1. PAGE VISIBILITY   — pauses automatically when the browser tab is hidden
//                          (web: document.visibilityState API) or app is
//                          backgrounded (mobile: WidgetsBindingObserver).
//                          Resumes immediately on return.
//
//   2. ADAPTIVE BACKOFF  — tracks whether each response actually changed.
//                          • Same data N times in a row → doubles interval
//                            (up to _maxInterval).
//                          • Data changed → resets to _baseInterval immediately.
//
//   3. SERVER-PUSH FIRST — if a WebSocket stream is provided, polling is
//                          suspended and the stream drives updates instead.
//                          Falls back to polling if stream closes/errors.
//
//   4. INTERVAL CLEANER  — IntervalCleaner singleton owns every timer and
//                          stream subscription. Calling IntervalCleaner.disposeAll()
//                          (e.g. on logout) guarantees zero leaks.
//
// Usage:
//
//   final poller = SmartPoller(
//     id:           'fleet',
//     base:         const Duration(seconds: 5),
//     max:          const Duration(seconds: 60),
//     fetch:        () => ApiService.get(ApiConfig.adminFleet),
//     onData:       (data) => _updateMarkers(data),
//     equality:     (a, b) => jsonEncode(a) == jsonEncode(b),
//     wsStream:     reverbChannel.stream,   // optional
//   );
//   poller.start();
//   // ...
//   poller.dispose();  // cancel timer + stream sub

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IntervalCleaner — global registry of every active timer/subscription
// ─────────────────────────────────────────────────────────────────────────────

class IntervalCleaner {
  IntervalCleaner._();
  static final IntervalCleaner _i = IntervalCleaner._();
  static IntervalCleaner get instance => _i;

  final Map<String, Timer>                    _timers = {};
  final Map<String, StreamSubscription<dynamic>> _subs = {};

  /// Register a timer under [id]. Replaces any existing timer with same id.
  void registerTimer(String id, Timer t) {
    _timers[id]?.cancel();
    _timers[id] = t;
  }

  /// Register a stream subscription under [id].
  void registerSub(String id, StreamSubscription sub) {
    _subs[id]?.cancel();
    _subs[id] = sub;
  }

  /// Cancel a specific timer by id.
  void cancelTimer(String id) {
    _timers.remove(id)?.cancel();
  }

  /// Cancel a specific subscription by id.
  void cancelSub(String id) {
    _subs.remove(id)?.cancel();
  }

  /// Cancel everything — call on logout / app dispose.
  void disposeAll() {
    for (final t in _timers.values) { t.cancel(); }
    for (final s in _subs.values)   { s.cancel(); }
    _timers.clear();
    _subs.clear();
    debugPrint('[IntervalCleaner] disposed all (${_timers.length + _subs.length} cleaned)');
  }

  int get activeTimers => _timers.length;
  int get activeSubs   => _subs.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// SmartPoller
// ─────────────────────────────────────────────────────────────────────────────

typedef FetchFn<T>    = Future<T> Function();
typedef OnDataFn<T>   = void Function(T data);
typedef EqualityFn<T> = bool Function(T? prev, T next);

class SmartPoller<T> with WidgetsBindingObserver {
  SmartPoller({
    required this.id,
    required Duration base,
    required Duration max,
    required this.fetch,
    required this.onData,
    this.equality,
    this.wsStream,
    this.stallThreshold = 3,
  })  : _base    = base,
        _max     = max,
        _current = base;

  /// Unique identifier — used as IntervalCleaner key.
  final String      id;
  final FetchFn<T>  fetch;
  final OnDataFn<T> onData;
  final EqualityFn<T>?     equality;
  final Stream<T>?         wsStream;

  /// How many identical responses before doubling the interval.
  final int stallThreshold;

  final Duration _base;
  final Duration _max;
  Duration       _current;

  T?   _prev;
  int  _stallCount   = 0;
  bool _paused       = false;
  bool _usingWs      = false;
  bool _disposed     = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  void start() {
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    _subscribePageVisibility();

    if (wsStream != null) {
      _attachWs();
    } else {
      _scheduleNext(_current);
    }
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    IntervalCleaner.instance.cancelTimer(id);
    debugPrint('[SmartPoller:$id] paused');
  }

  void resume() {
    if (!_paused || _disposed) return;
    _paused = false;
    if (!_usingWs) _scheduleNext(_current);
    debugPrint('[SmartPoller:$id] resumed (interval: ${_current.inSeconds}s)');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    IntervalCleaner.instance.cancelTimer(id);
    IntervalCleaner.instance.cancelSub('${id}_ws');
    IntervalCleaner.instance.cancelSub('${id}_vis');
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('[SmartPoller:$id] disposed');
  }

  // ── Page visibility ────────────────────────────────────────────────────────

  void _subscribePageVisibility() {
    if (kIsWeb) {
      // Web: listen to the document.visibilityState via a JS interop stream.
      // We use the existing WidgetsBindingObserver path which also fires on
      // web when the tab is hidden (Flutter maps hidden → inactive/paused).
    }
    // WidgetsBindingObserver covers both web tab hide and mobile background.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        resume();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        pause();
        break;
    }
  }

  // ── WebSocket path ────────────────────────────────────────────────────────

  void _attachWs() {
    _usingWs = true;
    // Cancel any existing poll timer — WS replaces it
    IntervalCleaner.instance.cancelTimer(id);

    final sub = wsStream!.listen(
      (data) {
        if (_disposed || _paused) return;
        _resetInterval();
        onData(data);
      },
      onError: (_) {
        debugPrint('[SmartPoller:$id] WS error — falling back to polling');
        _usingWs = false;
        IntervalCleaner.instance.cancelSub('${id}_ws');
        if (!_paused) _scheduleNext(_current);
      },
      onDone: () {
        debugPrint('[SmartPoller:$id] WS closed — falling back to polling');
        _usingWs = false;
        if (!_paused) _scheduleNext(_current);
      },
      cancelOnError: false,
    );
    IntervalCleaner.instance.registerSub('${id}_ws', sub);
    debugPrint('[SmartPoller:$id] WS attached — polling suspended');
  }

  // ── Poll scheduling ───────────────────────────────────────────────────────

  void _scheduleNext(Duration delay) {
    if (_disposed || _paused || _usingWs) return;
    IntervalCleaner.instance.cancelTimer(id);

    final t = Timer(delay, _tick);
    IntervalCleaner.instance.registerTimer(id, t);
  }

  Future<void> _tick() async {
    if (_disposed || _paused || _usingWs) return;
    try {
      final result = await fetch();
      _handleResult(result);
    } catch (e) {
      debugPrint('[SmartPoller:$id] fetch error: $e');
      // On error, back off a bit but don't exceed max
      _current = _clamp(_current * 1.5);
    } finally {
      // Schedule next tick regardless of success/failure
      if (!_disposed && !_paused && !_usingWs) {
        _scheduleNext(_current);
      }
    }
  }

  void _handleResult(T result) {
    final changed = _prev == null ||
        (equality != null
            ? !equality!(_prev, result)
            : _defaultEquality(_prev, result));

    if (changed) {
      _resetInterval();
      onData(result);
      _prev = result;
    } else {
      _stallCount++;
      if (_stallCount >= stallThreshold) {
        // Data is static — double the interval (exponential backoff)
        _current = _clamp(_current * 2);
        _stallCount = 0;
        debugPrint('[SmartPoller:$id] data unchanged — backed off to ${_current.inSeconds}s');
      }
    }
  }

  void _resetInterval() {
    _current    = _base;
    _stallCount = 0;
  }

  Duration _clamp(Duration d) =>
      d > _max ? _max : d;

  bool _defaultEquality(T? a, T? b) {
    try { return jsonEncode(a) == jsonEncode(b); } catch (_) { return a == b; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PollerMixin — attach to any State for one-liner usage
// ─────────────────────────────────────────────────────────────────────────────

/// Mixin for StatefulWidget — manages lifecycle automatically.
///
/// ```dart
/// class _MyState extends State<MyWidget> with PollerMixin {
///   @override
///   void initState() {
///     super.initState();
///     addPoller(SmartPoller(id: 'x', ...));
///   }
/// }
/// ```
mixin PollerMixin<T extends StatefulWidget> on State<T> {
  // "pollers" (no underscore) = accessible from the mixing-in class
  final List<SmartPoller> pollers = [];

  void addPoller(SmartPoller p) {
    pollers.add(p);
    p.start();
  }

  @override
  void dispose() {
    for (final p in pollers) { p.dispose(); }
    pollers.clear();
    super.dispose();
  }
}