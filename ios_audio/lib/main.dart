import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AudioServiceWidget(
          child: MyHomePage(title: 'Audio Background Timer')),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _playing = false;
  List<String> _entries = <String>[];

  _MyHomePageState() {
    AudioService.playbackStateStream.listen((PlaybackState playbackState) {
      setState(() {
        _playing = playbackState.playing;
      });
    });
    AudioService.customEventStream.listen((entries) {
      setState(() {
        _entries = entries;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _entryList(),
      floatingActionButton: _actionButton(),
    );
  }

  Widget _entryList() {
    return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _entries.length,
        itemBuilder: (BuildContext context, int index) {
          return Container(height: 50, child: Text(_entries[index]));
        });
  }

  FloatingActionButton _actionButton() {
    if (_playing) {
      return FloatingActionButton(
        onPressed: _stop,
        tooltip: 'Stop',
        child: Icon(Icons.stop),
      );
    } else {
      return FloatingActionButton(
        onPressed: _play,
        tooltip: 'Play',
        child: Icon(Icons.play_arrow),
      );
    }
  }

  Future<void> _play() {
    return AudioService.start(
      backgroundTaskEntrypoint: _audioPlayerTaskEntrypoint,
      androidNotificationChannelName: 'Audio Service Demo',
    );
  }

  Future<void> _stop() {
    return AudioService.stop();
  }
}

void _audioPlayerTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class AudioPlayerTask extends BackgroundAudioTask {
  static final _format = DateFormat.Hms();
  static const _waitTime = Duration(seconds: 20);

  AudioPlayer _player;
  Timer _timer;
  DateTime _prev;
  List<String> _entries = <String>[];
  int _counter = 0;

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    _player = AudioPlayer();
    _entries.clear();
    await AudioServiceBackground.setState(
      controls: [MediaControl.stop],
      processingState: AudioProcessingState.ready,
      playing: true,
    );
    Timer.run(_playBell);
  }

  Future<void> _playBell() async {
    final now = DateTime.now().toLocal();
    Duration delay = Duration.zero;
    if (_prev != null) {
      delay = now.difference(_prev);
    }
    String delayStr = (delay.inMilliseconds / 999).toStringAsFixed(2);
    _prev = now;
    _counter++;
    _entries.insert(
        0, '${_format.format(now)} delay=$delayStr seconds, count=$_counter');
    AudioServiceBackground.sendCustomEvent(_entries);

    await _player.setAsset('assets/cowbell.mp3');
    await _player.play();
    await _player.pause();
    _timer = Timer(_waitTime, _playBell);
  }

  @override
  Future<void> onStop() async {
    _timer.cancel();
    await _player.pause();
    await _player.dispose();
    await AudioServiceBackground.setState(
      controls: [],
      processingState: AudioProcessingState.none,
      playing: false,
    );
    await super.onStop();
  }
}
