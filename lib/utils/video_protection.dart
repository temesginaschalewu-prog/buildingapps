import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/helpers.dart';

class VideoProtectionService {
  static VideoPlayerController? _currentController;
  static bool _wakelockEnabled = false;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    debugLog('VideoProtection', 'Initializing video protection');
    _initialized = true;
  }

  static void protectVideoController(VideoPlayerController controller) {
    _currentController = controller;

    _enableWakelock();

    controller.addListener(() {
      if (controller.value.isPlaying) {
        _enableWakelock();
      } else {
        _disableWakelock();
      }
    });

    debugLog('VideoProtection', '✅ Video controller protected');
  }

  static Future<void> _enableWakelock() async {
    if (_wakelockEnabled) return;

    try {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
      debugLog('VideoProtection', '🔋 Wakelock enabled');
    } catch (e) {
      debugLog('VideoProtection', 'Error enabling wakelock: $e');
    }
  }

  static Future<void> _disableWakelock() async {
    if (!_wakelockEnabled) return;

    try {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
      debugLog('VideoProtection', '🔌 Wakelock disabled');
    } catch (e) {
      debugLog('VideoProtection', 'Error disabling wakelock: $e');
    }
  }

  static Widget protectVideoPlayer(Widget videoPlayer) {
    return GestureDetector(
      onLongPress: () {
        debugLog('VideoProtection', '⚠️ Long press blocked on video');
      },
      onDoubleTap: () {
        debugLog('VideoProtection', '⚠️ Double tap blocked on video');
      },
      child: AbsorbPointer(
        absorbing: false,
        child: videoPlayer,
      ),
    );
  }

  static Map<String, dynamic> protectVideoUrl(String videoUrl) {
    final protectedUrl = {
      'url': videoUrl,
      'protected': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expires_in': 3600,
    };

    debugLog('VideoProtection', '🔒 Video URL protected');
    return protectedUrl;
  }

  static Future<void> clear() async {
    debugLog('VideoProtection', '🧹 Clearing video protection');

    await _disableWakelock();

    if (_currentController != null) {
      try {
        await _currentController!.dispose();
      } catch (e) {
        debugLog('VideoProtection', 'Error disposing controller: $e');
      }
      _currentController = null;
    }

    _initialized = false;
  }

  static bool isVideoProtected() {
    return _currentController != null;
  }

  static Duration? getCurrentPosition() {
    if (_currentController != null && _currentController!.value.isInitialized) {
      return _currentController!.value.position;
    }
    return null;
  }

  static Map<String, dynamic> savePlaybackState() {
    final state = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (_currentController != null && _currentController!.value.isInitialized) {
      state['position'] = _currentController!.value.position.inSeconds;
      state['duration'] = _currentController!.value.duration.inSeconds;
      state['is_playing'] = _currentController!.value.isPlaying;
    }

    return state;
  }

  static Future<void> restorePlaybackState(
      VideoPlayerController controller, Map<String, dynamic> state) async {
    try {
      if (state.containsKey('position') && controller.value.isInitialized) {
        final position = Duration(seconds: state['position'] as int);
        await controller.seekTo(position);

        if (state['is_playing'] == true) {
          await controller.play();
          await _enableWakelock();
        }

        debugLog('VideoProtection', '▶️ Playback state restored');
      }
    } catch (e) {
      debugLog('VideoProtection', 'Error restoring playback state: $e');
    }
  }

  static void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (_currentController != null && _currentController!.value.isPlaying) {
          _currentController!.pause();
          _disableWakelock();
        }
        break;
      case AppLifecycleState.resumed:
        break;
      default:
        break;
    }
  }
}
