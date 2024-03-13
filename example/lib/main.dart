import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:audio_waveforms_example/chat_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Audio Waveforms',
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final RecorderController recorderController;

  String? path;
  String? musicFile;
  bool isRecording = false;
  bool isRecordingCompleted = false;
  bool isLoading = true;
  late Directory appDirectory;

  @override
  void initState() {
    super.initState();
    _getDir();
    _initialiseControllers();
  }

  void _getDir() async {
    appDirectory = await getApplicationDocumentsDirectory();
    path = "${appDirectory.path}/recording.m4a";
    isLoading = false;
    setState(() {});
  }

  void _initialiseControllers() {
    recorderController = RecorderController(useLegacyNormalization: true)
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..bitRate = 128000
      ..sampleRate = 44100;
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      musicFile = result.files.single.path;
      setState(() {});
    } else {
      debugPrint("File not picked");
    }
  }

  @override
  void dispose() {
    recorderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF252331),
      appBar: AppBar(
        backgroundColor: const Color(0xFF252331),
        elevation: 1,
        centerTitle: true,
        shadowColor: Colors.grey,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              scale: 1.5,
            ),
            const SizedBox(width: 10),
            const Text('Simform'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Expanded(
                  //   child: ListView.builder(
                  //     itemCount: 4,
                  //     itemBuilder: (_, index) {
                  //       return WaveBubble(
                  //         index: index + 1,
                  //         isSender: index.isOdd,
                  //         width: MediaQuery.of(context).size.width / 2,
                  //         appDirectory: appDirectory,
                  //       );
                  //     },
                  //   ),
                  // ),
                  if (isRecordingCompleted)
                    WaveBubble(
                      path: path,
                      isSender: true,
                      appDirectory: appDirectory,
                    ),
                  // if (musicFile != null)
                  //   WaveBubble(
                  //     path: musicFile,
                  //     isSender: true,
                  //     appDirectory: appDirectory,
                  //   ),
                  SafeArea(
                    child: Row(
                      children: [
                        Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isRecording
                              ? RecordPulsatingWidget(
                                  recorderController: recorderController,
                                )
                              : Container(
                                  width:
                                      MediaQuery.of(context).size.width / 1.7,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1B26),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  padding: const EdgeInsets.only(left: 18),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 15),
                                  child: TextField(
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      hintText: "Type Something...",
                                      hintStyle: const TextStyle(
                                          color: Colors.white54),
                                      contentPadding:
                                          const EdgeInsets.only(top: 16),
                                      border: InputBorder.none,
                                      suffixIcon: IconButton(
                                        onPressed: _pickFile,
                                        icon: Icon(Icons.adaptive.share),
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        IconButton(
                          onPressed: _refreshWave,
                          icon: Icon(
                            isRecording ? Icons.refresh : Icons.send,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: _startOrStopRecording,
                          icon: Icon(isRecording ? Icons.stop : Icons.mic),
                          color: Colors.white,
                          iconSize: 28,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _startOrStopRecording() async {
    try {
      if (isRecording) {
        recorderController.reset();

        final path = await recorderController.stop(false);

        if (path != null) {
          isRecordingCompleted = true;
          debugPrint(path);
          debugPrint("Recorded file size: ${File(path).lengthSync()}");
        }
      } else {
        await recorderController.record(path: path!);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        isRecording = !isRecording;
      });
    }
  }

  void _refreshWave() {
    if (isRecording) recorderController.refresh();
  }
}

class RecordPulsatingWidget extends StatefulWidget {
  const RecordPulsatingWidget({Key? key, required this.recorderController})
      : super(key: key);
  final RecorderController recorderController;

  @override
  State<RecordPulsatingWidget> createState() => _RecordPulsatingWidgetState();
}

class _RecordPulsatingWidgetState extends State<RecordPulsatingWidget> {
  late Timer _timer;
  double pulsatingValue = 0;

  @override
  void initState() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (mounted && widget.recorderController.waveData.isNotEmpty) {
        setState(() {
          var value = widget.recorderController.waveData.last;
          if (value == 0) return;
          dev.log(value.toString());
          pulsatingValue = value;
        });
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SqAvatarWidget(
      color: Colors.yellow,
      size: 100,
      pulsatingValue: pulsatingValue,
    );
  }
}

class SqAvatarWidget extends StatelessWidget {
  const SqAvatarWidget({
    Key? key,
    required this.color,
    required this.size,
    this.pulsatingValue = 0,
    this.progress = 0,
    this.progressColor = Colors.green,
    Color? backgroundColor,
  })  : backgroundColor = backgroundColor ?? color,
        super(key: key);
  final Color color;
  final double size;
  final double pulsatingValue;
  final double progress;
  final Color progressColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0 + (pulsatingValue * 0.35);

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: scale,
          child: CustomPaint(
            painter: SquirclePainter(color: const Color(0xffececec)),
            size: Size(size, size),
          ),
        ),
        CustomPaint(
          size: Size(size, size),
          painter: SquirclePainter(
            color: color,
            progress: progress,
          ),
        ),
      ],
    );
  }
}

class SquirclePainter extends CustomPainter {
  final Color color;
  final double progress;
  SquirclePainter({required this.color, this.progress = 0});

  Offset superellipsePoint(double angle, double width, double height) {
    const n = 4.0;
    final cosA = cos(angle);
    final sinA = sin(angle);

    final x = pow((cosA).abs(), 2.0 / n) * width * cosA.sign / 2;
    final y = pow((sinA).abs(), 2.0 / n) * height * sinA.sign / 2;

    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint progressPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    const step = pi / 360;
    final Path progressPath = Path();
    final Path path = Path();

    final start = superellipsePoint(pi / 2, size.width, size.height);
    path.moveTo(center.dx + start.dx, center.dy + start.dy);
    progressPath.moveTo(center.dx + start.dx, center.dy + start.dy);

    for (double angle = pi / 2; angle < (pi / 2) + (2 * pi); angle += step) {
      final point = superellipsePoint(angle, size.width, size.height);
      path.lineTo(center.dx + point.dx, center.dy + point.dy);
    }

    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(progressPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
