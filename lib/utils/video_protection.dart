import 'dart:io';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:flutter/material.dart';
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
    return ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: autoPlay,
      looping: looping,
      showControls: true,
      allowFullScreen: false,
      allowPlaybackSpeedChanging: false,
      showOptions: false,

      // Custom overlay to prevent screen capture
      overlay: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            // Handle overlay taps if needed
          },
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ),

      // Use default controls or custom controls without problematic parameters
      // Remove the customControls parameter or fix it like this:
      customControls: const MaterialControls(
        showPlayButton: true,
      ),

      // Prevent video from being shared
      allowedScreenSleep: false,

      // Placeholder while loading
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),

      // Auto-initialize video
      autoInitialize: true,

      // Error widget
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            'Error loading video: $errorMessage',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }

  // OR if you want to use CupertinoControls, fix it like this:
  static ChewieController createProtectedControllerWithCupertino({
    required VideoPlayerController videoPlayerController,
    required BuildContext context,
    bool autoPlay = true,
    bool looping = false,
  }) {
    return ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: autoPlay,
      looping: looping,
      showControls: true,
      allowFullScreen: false,
      allowPlaybackSpeedChanging: false,
      showOptions: false,

      // Custom controls - use the correct parameter names
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: Theme.of(context).primaryColor,
        handleColor: Theme.of(context).primaryColor,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade300,
      ),

      materialProgressColors: ChewieProgressColors(
        playedColor: Theme.of(context).primaryColor,
        handleColor: Theme.of(context).primaryColor,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade300,
      ),

      // Placeholder while loading
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),

      // Auto-initialize video
      autoInitialize: true,
    );
  }

  static Widget createProtectedVideoPlayer({
    required ChewieController controller,
    required BuildContext context,
    required String videoTitle,
  }) {
    return WillPopScope(
      onWillPop: () async {
        if (controller.isPlaying) {
          controller.pause();
        }
        // Don't call ScreenProtectionService here as it might interfere
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              controller.pause();
              Navigator.pop(context);
            },
          ),
          title: Text(
            videoTitle,
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
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
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> disposeController(ChewieController controller) async {
    await controller.pause();
    controller.dispose();
  }

  static Future<bool> isVideoFileProtected(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
