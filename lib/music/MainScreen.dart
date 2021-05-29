import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'audioService.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Service Demo'),
      ),
      body: Container(
        child: SingleChildScrollView(
          child: StreamBuilder<bool>(
              stream: AudioService.runningStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.active) {
                  // Don't show anything until we've ascertained whether or not the
                  // service is running, since we want to show a different UI in
                  // each case.
                  return SizedBox();
                }
                final running = snapshot.data ?? false;
                return Column(
                  children: [
                    SizedBox(
                      height: 20,
                    ),
                    StreamBuilder<MediaState>(
                      stream: _mediaStateStream,
                      builder: (context, snapshot) {
                        final mediaState = snapshot.data;
                        return SeekBar(
                          duration:
                              mediaState?.mediaItem?.duration ?? Duration.zero,
                          position: mediaState?.position ?? Duration.zero,
                          onChangeEnd: (newPosition) {
                            AudioService.seekTo(newPosition);
                          },
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 30, right: 30),
                      child: StreamBuilder<bool>(
                          stream: AudioService.playbackStateStream
                              .map((state) => state.playing)
                              .distinct(),
                          builder: (context, snapshot) {
                            final playing = snapshot.data ?? false;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    FeatherIcons.skipBack,
                                    color: Colors.black.withOpacity(0.8),
                                    size: 25,
                                  ),
                                  onPressed: () {},
                                ),
                                playing ? pauseButton() : playButton(running),
                                stopButton(),
                                IconButton(
                                  icon: Icon(
                                    FeatherIcons.skipForward,
                                    color: Colors.black.withOpacity(0.8),
                                    size: 25,
                                  ),
                                  onPressed: () {},
                                ),
                              ],
                            );
                          }),
                    )
                  ],
                );
              }),
        ),
      ),
    );
  }

  /// A stream reporting the combined state of the current media item and its
  /// current position.
  Stream<MediaState> get _mediaStateStream =>
      Rx.combineLatest2<MediaItem?, Duration, MediaState>(
          AudioService.currentMediaItemStream,
          AudioService.positionStream,
          (mediaItem, position) => MediaState(mediaItem, position));

  /// A stream reporting the combined state of the current queue and the current
  /// media item within that queue.
  Stream<QueueState> get _queueStateStream =>
      Rx.combineLatest2<List<MediaItem>?, MediaItem?, QueueState>(
          AudioService.queueStream,
          AudioService.currentMediaItemStream,
          (queue, mediaItem) => QueueState(queue, mediaItem));

  ElevatedButton audioPlayerButton() => startButton(
        'AudioPlayer',
        () {
          AudioService.start(
            backgroundTaskEntrypoint: () => audioPlayerTaskEntrypoint(),
            androidNotificationChannelName: 'Audio Service Demo',
            // Enable this if you want the Android service to exit the foreground state on pause.
            //androidStopForegroundOnPause: true,
            androidNotificationColor: 0xFF2196f3,
            androidNotificationIcon: 'mipmap/ic_launcher',
            androidEnableQueue: true,
          );
        },
      );

  ElevatedButton startButton(String label, VoidCallback onPressed) =>
      ElevatedButton(
        child: Text(label),
        onPressed: onPressed,
      );

  IconButton playButton(bool running) => IconButton(
      iconSize: 50,
      icon: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.orange,
        ),
        child: Center(
          child: Icon(
            FeatherIcons.play,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      onPressed: () {
        if (!running) {
          AudioService.start(
            backgroundTaskEntrypoint: audioPlayerTaskEntrypoint,
            androidNotificationChannelName: 'Audio Service Demo',
            // Enable this if you want the Android service to exit the foreground state on pause.
            //androidStopForegroundOnPause: true,
            androidNotificationColor: 0xFF2196f3,
            androidNotificationIcon: 'mipmap/ic_launcher',
            androidEnableQueue: true,
          );
        }

        _play();
      });

  void _play() => AudioService.play();

  IconButton pauseButton() => IconButton(
        iconSize: 50,
        icon: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange,
          ),
          child: Center(
            child: Icon(
              FeatherIcons.pause,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        onPressed: AudioService.pause,
      );

  IconButton stopButton() => IconButton(
        iconSize: 50,
        icon: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange,
          ),
          child: Center(
            child: Icon(
              FeatherIcons.square,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        onPressed: AudioService.stop,
      );
}

class SeekBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final ValueChanged<Duration>? onChanged;
  final ValueChanged<Duration>? onChangeEnd;

  SeekBar({
    required this.duration,
    required this.position,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final value = min(_dragValue ?? widget.position.inMilliseconds.toDouble(),
        widget.duration.inMilliseconds.toDouble());
    if (_dragValue != null && !_dragging) {
      _dragValue = null;
    }

    Duration position = new Duration();

    Duration musicLength = new Duration();

    return Column(
      children: [
        Slider(
          activeColor: Colors.orange,
          inactiveColor: Colors.green,
          min: 0.0,
          max: widget.duration.inMilliseconds.toDouble(),
          value: value,
          onChanged: (value) {
            if (!_dragging) {
              _dragging = true;
            }
            setState(() {
              _dragValue = value;
            });
            if (widget.onChanged != null) {
              widget.onChanged!(Duration(milliseconds: value.round()));
            }
          },
          onChangeEnd: (value) {
            if (widget.onChangeEnd != null) {
              widget.onChangeEnd!(Duration(milliseconds: value.round()));
            }
            _dragging = false;
          },
        ),
        /* Positioned(
          right: 16.0,
          bottom: 0.0,
          child: Text(
              RegExp(r'((^0*[1-9]\d*:)?\d{2}:\d{2})\.\d+$')
                      .firstMatch("$_remaining")
                      ?.group(1) ??
                  '$_remaining',
              style: Theme.of(context).textTheme.caption),
        ), */
        Padding(
          padding: const EdgeInsets.only(left: 30, right: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.position.inMinutes.toString() +
                    ":" +
                    widget.position.inSeconds.remainder(60).toString(),
                style: TextStyle(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              Text(
                widget.duration.inMinutes.toString() +
                    ":" +
                    widget.duration.inSeconds.remainder(60).toString(),
                style: TextStyle(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 25,
        ),
      ],
    );
  }

  Duration get _remaining => widget.duration - widget.position;
}
