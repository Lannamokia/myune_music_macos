import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'platform_media_service.dart';

class MacOSMediaService implements PlatformMediaService {
  static const MethodChannel _channel = MethodChannel('macos_media_service');
  
  Timer? _timelineUpdateTimer;
  int? _lastPosition;
  int? _lastDuration;

  MacOSMediaService({
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
    Future<void> Function()? onNext,
    Future<void> Function()? onPrevious,
  }) {
    _setupMethodCallHandler(onPlay, onPause, onNext, onPrevious);
    _initializeMediaService();
  }

  void _setupMethodCallHandler(
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
    Future<void> Function()? onNext,
    Future<void> Function()? onPrevious,
  ) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlay':
          await onPlay?.call();
          break;
        case 'onPause':
          await onPause?.call();
          break;
        case 'onNext':
          await onNext?.call();
          break;
        case 'onPrevious':
          await onPrevious?.call();
          break;
        default:
          debugPrint('未知的媒体控制事件: ${call.method}');
      }
    });
  }

  Future<void> _initializeMediaService() async {
    try {
      await _channel.invokeMethod('initialize');
      debugPrint('macOS媒体服务初始化成功');
    } catch (e) {
      debugPrint('初始化macOS媒体服务失败: $e');
      // 在macOS上，如果原生插件不可用，我们提供一个简化的实现
      debugPrint('使用简化的macOS媒体服务实现');
    }
  }

  @override
  Future<void> updateMetadata({
    required String title,
    required String artist,
    String? album,
    Uint8List? albumArt,
  }) async {
    try {
      await _channel.invokeMethod('updateMetadata', {
        'title': title,
        'artist': artist,
        'album': album ?? '',
        'albumArt': albumArt,
      });
    } catch (e) {
      debugPrint('更新macOS媒体元数据失败: $e');
    }
  }

  @override
  Future<void> updateState(bool isPlaying) async {
    try {
      await _channel.invokeMethod('updateState', {
        'isPlaying': isPlaying,
      });
    } catch (e) {
      debugPrint('更新macOS媒体状态失败: $e');
    }
  }

  @override
  Future<void> updateTimeline({
    required Duration position,
    required Duration duration,
  }) async {
    // 防抖
    final positionMs = position.inMilliseconds;
    final durationMs = duration.inMilliseconds;
    if (_lastPosition == positionMs && _lastDuration == durationMs) return;

    _lastPosition = positionMs;
    _lastDuration = durationMs;

    if (_timelineUpdateTimer?.isActive ?? false) return;
    _timelineUpdateTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _channel.invokeMethod('updateTimeline', {
          'position': positionMs,
          'duration': durationMs,
        });
      } catch (e) {
        debugPrint('更新macOS媒体时间轴失败: $e');
      }
    });
  }

  @override
  Future<void> dispose() async {
    _timelineUpdateTimer?.cancel();
    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {
      debugPrint('关闭macOS媒体服务失败: $e');
    }
  }
}