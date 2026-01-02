import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoProtection {
  static ChewieController createProtectedController({
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
      materialProgressColors: ChewieProgressColors(
        playedColor: Theme.of(context).primaryColor,
        handleColor: Theme.of(context).primaryColor,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade300,
      ),
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      autoInitialize: true,
      overlay: Container(
        color: Colors.transparent,
      ),
      customControls: const CupertinoControls(
        backgroundColor: Color.fromRGBO(0, 0, 0, 0.9),
        iconColor: Color.fromARGB(255, 200, 200, 200),
      ),
    );
  }

  static Widget createProtectedVideoPlayer({
    required ChewieController controller,
    required BuildContext context,
  }) {
    return WillPopScope(
      onWillPop: () async {
        if (controller.isPlaying) {
          controller.pause();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
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
              if (controller.isPlaying)
                GestureDetector(
                  onTap: () {
                    if (controller.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  },
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
