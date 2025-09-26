import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import '../page/playlist/playlist_content_notifier.dart';
import 'hover_overlay_control.dart';

class VolumeControl extends StatefulWidget {
  final Player player;
  final Color iconColor;

  const VolumeControl({
    required this.player,
    required this.iconColor,
    super.key,
  });

  @override
  _VolumeControlState createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  @override
  void initState() {
    super.initState();
  }

  // 处理滚轮事件，增加/减少音量
  void _handleScroll(
    PointerSignalEvent event,
    PlaylistContentNotifier playlistNotifier,
  ) {
    if (event is PointerScrollEvent) {
      const double step = 3.0;
      final newVolume =
          (playlistNotifier.volume - event.scrollDelta.dy.sign * step).clamp(
            0.0,
            100.0,
          );
      playlistNotifier.setVolume(newVolume);
    }
  }

  // 获取当前应显示的音量图标
  IconData _getVolumeIcon(double volume) {
    if (volume < 1.0) return Icons.volume_off;
    if (volume <= 50.0) {
      return Icons.volume_down;
    }
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistContentNotifier>(
      builder: (context, playlistNotifier, child) {
        return HoverOverlayControl(
          icon: _getVolumeIcon(playlistNotifier.volume),
          iconColor: widget.iconColor,
          onIconPressed: playlistNotifier.toggleMute,
          onPointerSignal: (event) => _handleScroll(event, playlistNotifier),
          overlayOffset: const Offset(0, -170),
          overlayConstraints: const BoxConstraints(maxWidth: 40),
          overlayContentBuilder: (context) {
            // 将滑块内容独立出来，不受Consumer重建影响
            return _VolumeSliderWidget(
              playlistNotifier: playlistNotifier,
            );
          },
        );
      },
    );
  }

}

// 独立的音量滑块组件，不受外部Consumer重建影响
class _VolumeSliderWidget extends StatefulWidget {
  final PlaylistContentNotifier playlistNotifier;

  const _VolumeSliderWidget({
    required this.playlistNotifier,
  });

  @override
  State<_VolumeSliderWidget> createState() => _VolumeSliderWidgetState();
}

class _VolumeSliderWidgetState extends State<_VolumeSliderWidget> {
  double? _localVolume;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 120,
            child: RotatedBox(
              quarterTurns: -1, // 横向滑块旋转成垂直显示
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  value: _isDragging ? (_localVolume ?? widget.playlistNotifier.volume) : widget.playlistNotifier.volume,
                  min: 0,
                  max: 100,
                  onChanged: (value) {
                    setState(() {
                      _localVolume = value;
                      _isDragging = true;
                    });
                    // 拖动期间使用即时设置，不触发UI重建
                    widget.playlistNotifier.setVolumeInstant(value);
                  },
                  onChangeStart: (value) {
                    setState(() {
                      _isDragging = true;
                      _localVolume = widget.playlistNotifier.volume; // 使用当前音量作为起始值
                    });
                  },
                  onChangeEnd: (value) {
                    // 先设置最终音量，再重置状态
                    widget.playlistNotifier.setVolume(value);
                    setState(() {
                      _isDragging = false;
                      _localVolume = null;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(_isDragging ? (_localVolume ?? widget.playlistNotifier.volume) : widget.playlistNotifier.volume).round()}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
