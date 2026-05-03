import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/content_models.dart';
import '../services/tv_api_service.dart';
import '../widgets/tv_focus_card.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.video,
    required this.chapterId,
  });

  final VideoItem video;
  final int chapterId;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  late TvApiService _api;
  bool _loading = true;
  String? _error;
  bool _showControls = true;
  Duration _lastSavedPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _api = context.read<TvApiService>();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.preferredUrl),
      );
      await controller.initialize();
      await controller.play();
      controller.addListener(_handleProgressTick);
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _handleProgressTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    if ((position - _lastSavedPosition).inSeconds.abs() < 15 &&
        position != controller.value.duration) {
      return;
    }
    _lastSavedPosition = position;
    _saveProgress(position);
  }

  void _saveProgress(Duration position) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return;
    final percent =
        ((position.inMilliseconds / duration.inMilliseconds) * 100).round().clamp(0, 100);
    _api.saveUserProgress(
          chapterId: widget.chapterId,
          videoProgress: percent,
        ).catchError((_) {});
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    setState(() => _showControls = true);
  }

  Future<void> _seekRelative(Duration offset) async {
    final controller = _controller;
    if (controller == null) return;

    final current = controller.value.position;
    final total = controller.value.duration;
    final next = current + offset;
    final safe = next < Duration.zero
        ? Duration.zero
        : (next > total ? total : next);

    await controller.seekTo(safe);
    setState(() => _showControls = true);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      _seekRelative(const Duration(seconds: 15));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      _seekRelative(const Duration(seconds: -15));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _showControls = true);
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:$seconds';
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      _saveProgress(controller.value.position);
      controller.removeListener(_handleProgressTick);
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final player = controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.video.title)),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      'Could not start playback.\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  )
                : player == null
                    ? const Center(
                        child: Text(
                          'Player is not ready yet.',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final isPortraitVideo =
                                        player.value.size.width > 0 &&
                                        player.value.size.height > 0 &&
                                        player.value.size.height > player.value.size.width;
                                    return FittedBox(
                                      fit: isPortraitVideo
                                          ? BoxFit.contain
                                          : BoxFit.cover,
                                      clipBehavior: Clip.hardEdge,
                                      child: SizedBox(
                                        width: player.value.size.width == 0
                                            ? 1920
                                            : player.value.size.width,
                                        height: player.value.size.height == 0
                                            ? 1080
                                            : player.value.size.height,
                                        child: VideoPlayer(player),
                                      ),
                                    );
                                  },
                                ),
                                if (_showControls)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0x99000000),
                                            Color(0x22000000),
                                            Color(0x99000000),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_showControls)
                                  Positioned(
                                    left: 24,
                                    right: 24,
                                    bottom: 24,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.video.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            value: player.value.duration.inMilliseconds == 0
                                                ? 0
                                                : player.value.position.inMilliseconds /
                                                    player.value.duration.inMilliseconds,
                                            minHeight: 8,
                                            backgroundColor: Colors.white24,
                                            valueColor: const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF4EA1FF),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${_formatDuration(player.value.position)} / ${_formatDuration(player.value.duration)}',
                                          style: const TextStyle(
                                            color: Color(0xFFD6E0F5),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 220,
                                  child: TvFocusCard(
                                    autofocus: true,
                                    onPressed: _togglePlayPause,
                                    child: Center(
                                      child: Text(
                                        player.value.isPlaying ? 'Pause' : 'Play',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 220,
                                  child: TvFocusCard(
                                    onPressed: () =>
                                        _seekRelative(const Duration(seconds: -15)),
                                    child: const Center(
                                      child: Text(
                                        'Back 15s',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 220,
                                  child: TvFocusCard(
                                    onPressed: () =>
                                        _seekRelative(const Duration(seconds: 15)),
                                    child: const Center(
                                      child: Text(
                                        'Forward 15s',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
