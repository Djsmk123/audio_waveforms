import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:audio_waveforms_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isSender;
  final bool isLast;

  const ChatBubble({
    Key? key,
    required this.text,
    this.isSender = false,
    this.isLast = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 10, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isSender) const Spacer(),
              Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSender
                        ? const Color(0xFF276bfd)
                        : const Color(0xFF343145)),
                padding: const EdgeInsets.only(
                    bottom: 9, top: 8, left: 14, right: 12),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WaveBubble extends StatefulWidget {
  final bool isSender;
  final int? index;
  final String? path;
  final double? width;
  final Directory appDirectory;

  const WaveBubble({
    Key? key,
    required this.appDirectory,
    this.width,
    this.index,
    this.isSender = false,
    this.path,
  }) : super(key: key);

  @override
  State<WaveBubble> createState() => _WaveBubbleState();
}

class _WaveBubbleState extends State<WaveBubble> {
  File? file;

  late PlayerController controller;
  late StreamSubscription<PlayerState> playerStateSubscription;

  final playerWaveStyle = const PlayerWaveStyle(
    fixedWaveColor: Colors.white54,
    liveWaveColor: Colors.white,
    spacing: 6,
  );
  double pulsatingValue = 0;

  int getRandome(int max) {
    var random = new Random();
    var value = random.nextInt(max);
    return value;
  }

  @override
  void initState() {
    super.initState();
    controller = PlayerController();
    _preparePlayer();
    playerStateSubscription = controller.onPlayerStateChanged.listen((_) {
      setState(() {});
    });
    controller.onCurrentDurationChanged.listen((progress) {
      setState(() {
        var value = controller.waveformData[
            (((controller.waveformData.length - 2) *
                    progress /
                    controller.maxDuration)
                .round())];
        print(value);
        pulsatingValue = value * 4.5;

        // log('pulsatingValue: $pulsatingValue');
      });
    });
  }

  void _preparePlayer() async {
    // Opening file from assets folder
    if (widget.index != null) {
      file = File('${widget.appDirectory.path}/audio${widget.index}.mp3');
      await file?.writeAsBytes(
          (await rootBundle.load('assets/audios/audio${widget.index}.mp3'))
              .buffer
              .asUint8List());
    }

    if (widget.index == null && widget.path == null && file?.path == null) {
      return;
    }
    // Prepare player with extracting waveform if index is even.
    // controller.preparePlayer(
    //   path: widget.path ?? file!.path,
    //   shouldExtractWaveform: widget.index?.isEven ?? true,
    // );
    List urls = [
      "https://storage.googleapis.com/perpetuum-d997d.appspot.com/audio/8ce44188-1afd-4e37-ba8a-c380042e9455-1699025454438-audio.x-wav",
      "https://storage.googleapis.com/perpetuum-d997d.appspot.com/audio/dab18419-8030-4fb7-be0c-5b6df56c2afa-1699030144670-audio.x-wav",
      "https://storage.googleapis.com/perpetuum-d997d.appspot.com/audio/b93c20a3-9290-45b9-89a3-5c91c0532340-1699018806589-audio.x-wav",
      "https://storage.googleapis.com/perpetuum-d997d.appspot.com/audio/b93c20a3-9290-45b9-89a3-5c91c0532340-1699018806589-audio.x-wav",
      "https://storage.googleapis.com/perpetuum-d997d.appspot.com/audio/b93c20a3-9290-45b9-89a3-5c91c0532340-1699018806589-audio.x-wav",
      "https://storage.googleapis.com/perpetuum-d997d.appspot.com/audio/b93c20a3-9290-45b9-89a3-5c91c0532340-1699018806589-audio.x-wav",
      "https://storage.googleapis.com/perpetuum-d997d.appspot.com/audio/b93c20a3-9290-45b9-89a3-5c91c0532340-1699018806589-audio.x-wav",
      "https://storage.googleapis.com/perpetuum-d997d.appspot.com/audio/b93c20a3-9290-45b9-89a3-5c91c0532340-1699018806589-audio.x-wav",
    ];
    controller.preparePlayer(
      //url: urls[getRandome(urls.length)],
      path: widget.path ?? file!.path,
      shouldExtractWaveform: true,
    );
    // Extracting waveform separately if index is odd.
    if (widget.index?.isOdd ?? false) {
      controller
          .extractWaveformData(
            path: widget.path ?? file!.path,
            noOfSamples:
                playerWaveStyle.getSamplesForWidth(widget.width ?? 200),
          )
          .then((waveformData) => debugPrint(waveformData.toString()));
    }
  }

  @override
  void dispose() {
    playerStateSubscription.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.path != null || file?.path != null
        ? Align(
            alignment:
                widget.isSender ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.only(
                bottom: 6,
                right: widget.isSender ? 0 : 10,
                top: 6,
              ),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: widget.isSender ? Colors.black : const Color(0xFF343145),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SqAvatarWidget(
                    pulsatingValue: pulsatingValue,
                    color: Colors.purple,
                    size: 70,
                  ),
                  if (!controller.playerState.isStopped)
                    IconButton(
                      onPressed: () async {
                        controller.playerState.isPlaying
                            ? await controller.pausePlayer()
                            : await controller.startPlayer(
                                finishMode: FinishMode.pause,
                              );
                      },
                      icon: Icon(
                        controller.playerState.isPlaying
                            ? Icons.stop
                            : Icons.play_arrow,
                      ),
                      color: Colors.white,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                  // AudioFileWaveforms(
                  //   size: Size(MediaQuery.of(context).size.width / 2, 70),
                  //   playerController: controller,
                  //   waveformType: widget.index?.isOdd ?? false
                  //       ? WaveformType.fitWidth
                  //       : WaveformType.long,
                  //   playerWaveStyle: playerWaveStyle,
                  // ),
                  if (widget.isSender) const SizedBox(width: 10),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
