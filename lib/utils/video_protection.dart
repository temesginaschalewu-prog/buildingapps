import 'dart:io';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoProtection {
  static ChewieController createProtectedController({
    required VideoPlayerController videoPlayerController,
    required BuildContext context,
    required String videoUrl,
    bool autoPlay = true,
    bool looping = false,
  }) {
    // Ensure HTTPS URL
    final secureVideoUrl = _ensureHttpsUrl(videoUrl);

    return ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: autoPlay,
      looping: looping,
      showControls: true,
      allowFullScreen: false, // Disable fullscreen to maintain protection
      allowPlaybackSpeedChanging: false,
      showOptions: false,
      customControls: const MaterialControls(
        showPlayButton: true,
      ),
      allowedScreenSleep: false,
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      autoInitialize: true,
      errorBuilder: (context, errorMessage) {
        debugPrint('Video player error: $errorMessage');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading video',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'URL: ${secureVideoUrl.substring(0, 50)}...',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _ensureHttpsUrl(String url) {
    // If URL is localhost or HTTP, convert to Render HTTPS URL
    if (url.contains('http://192.168') || url.contains('http://localhost')) {
      // Extract the path from the URL
      final uri = Uri.parse(url);
      final path = uri.path;

      // Use the production base URL
      return 'https://family-academy-backend.onrender.com$path';
    }

    // Already HTTPS or external URL
    return url;
  }

  static Widget createProtectedVideoPlayer({
    required ChewieController controller,
    required BuildContext context,
    required String videoTitle,
    required VoidCallback onDispose,
  }) {
    // Enable video protection when screen builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenProtectionService.protectVideoPlayback();
    });

    return WillPopScope(
      onWillPop: () async {
        // Restore protection and dispose
        await disposeController(controller, onDispose);
        return true;
      },
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                await disposeController(controller, onDispose);
                Navigator.pop(context);
              },
            ),
            title: Text(
              videoTitle,
              style: const TextStyle(color: Colors.white),
            ),
            centerTitle: true,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: () {
                  // Prevent fullscreen to maintain protection
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio:
                        controller.videoPlayerController.value.aspectRatio,
                    child: Chewie(controller: controller),
                  ),
                ),
                // Overlay to prevent taps during playback
                if (controller.isPlaying)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        // Do nothing - prevents interaction
                      },
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> disposeController(
      ChewieController controller, VoidCallback onDispose) async {
    await controller.pause();
    controller.dispose();
    // Restore normal screen protection
    await ScreenProtectionService.restoreAfterVideo();
    onDispose();
  }

  // Method to handle screen orientation for video
  static Future<void> lockVideoOrientation() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  static Future<void> unlockVideoOrientation() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }
}
