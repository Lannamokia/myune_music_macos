import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../page/playlist/playlist_models.dart';
import '../page/setting/settings_provider.dart';

class DesktopLyricsManager {
  static const MethodChannel _channel = MethodChannel('macos_media_service');
  
  static DesktopLyricsManager? _instance;
  static DesktopLyricsManager get instance {
    _instance ??= DesktopLyricsManager._internal();
    return _instance!;
  }

  DesktopLyricsManager._internal() {
    // 监听来自原生端的回调
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // 设置提供者
  SettingsProvider? _settingsProvider;

  // 桌面悬浮歌词相关
  bool _isEnabled = false;
  bool _isVisible = false;
  String _currentLyric = '';
  Timer? _updateTimer;
  
  // 歌词数据
  List<LyricLine> _lyrics = [];
  Duration _currentPosition = Duration.zero;
  int _currentLyricIndex = -1;
  
  // 回调函数
  Function()? _onStateChanged;
  Function(String)? _onMediaControlCallback;
  
  // 歌曲信息
  String _currentSongTitle = '';
  String _currentArtist = '';

  // 悬浮窗口样式配置
  double _fontSize = 24.0;
  String _fontColor = '#FFFFFF';
  String _backgroundColor = '#80000000'; // 半透明黑色
  double _windowOpacity = 0.8;
  bool _enableShadow = true;
  String _position = 'top'; // top, center, bottom

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isVisible => _isVisible;
  String get currentLyric => _currentLyric;
  List<LyricLine> get lyrics => _lyrics;
  int get currentLyricIndex => _currentLyricIndex;
  String get currentSongTitle => _currentSongTitle;
  String get currentArtist => _currentArtist;
  double get fontSize => _fontSize;
  String get fontColor => _fontColor;
  String get backgroundColor => _backgroundColor;
  double get windowOpacity => _windowOpacity;
  bool get enableShadow => _enableShadow;
  String get position => _position;

  /// 处理来自原生端的方法调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDesktopLyricsDisabled':
        // 用户禁用了桌面悬浮歌词
        _isEnabled = false;
        _isVisible = false;
        _stopUpdateTimer();
        _clearCurrentLyric();
        
        // 同步更新设置中的开关状态
        if (_settingsProvider != null) {
          _settingsProvider!.setEnableDesktopLyrics(false);
        }
        
        _notifyStateChanged();
        break;
      case 'onDesktopLyricsPositionChanged':
        // 用户拖动了悬浮窗口位置
        final position = call.arguments as Map<String, dynamic>;
        print('桌面歌词窗口位置已更改: $position');
        break;
      case 'onTogglePlayPause':
        // 用户点击了播放/暂停按钮
        _onMediaControlCallback?.call('togglePlayPause');
        break;
      case 'onPrevious':
        // 用户点击了上一曲按钮
        _onMediaControlCallback?.call('previous');
        break;
      case 'onNext':
        // 用户点击了下一曲按钮
        _onMediaControlCallback?.call('next');
        break;
    }
  }

  /// 设置状态变化回调
  void setOnStateChanged(Function() callback) {
    _onStateChanged = callback;
  }

  /// 设置媒体控制回调
  void setOnMediaControl(Function(String) callback) {
    _onMediaControlCallback = callback;
  }

  /// 设置设置提供者
  void setSettingsProvider(SettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
  }

  /// 通知状态变化
  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 初始化桌面悬浮歌词功能
  Future<bool> initialize() async {
    if (!Platform.isMacOS) {
      print('桌面悬浮歌词功能仅支持 macOS');
      return false;
    }

    try {
      print('桌面悬浮歌词管理器初始化成功');
      return true;
    } catch (e) {
      print('桌面悬浮歌词管理器初始化失败: $e');
      return false;
    }
  }

  /// 启用桌面悬浮歌词
  Future<void> enable({int delaySeconds = 2}) async {
    if (!Platform.isMacOS || _isEnabled) return;

    try {
      if (!await initialize()) {
        return;
      }

      // 从设置提供者获取最新的样式配置
      if (_settingsProvider != null) {
        _fontSize = _settingsProvider!.desktopLyricsFontSize;
        _fontColor = '#${_settingsProvider!.desktopLyricsTextColor.value.toRadixString(16).padLeft(8, '0')}';
        _backgroundColor = '#${_settingsProvider!.desktopLyricsBackgroundColor.value.toRadixString(16).padLeft(8, '0')}';
      }

      // 添加启动延迟
      if (delaySeconds > 0) {
        print('桌面悬浮歌词将在 $delaySeconds 秒后显示');
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      await _channel.invokeMethod('enableDesktopLyrics', {
        'fontSize': _fontSize,
        'fontColor': _fontColor,
        'backgroundColor': _backgroundColor,
        'windowOpacity': _windowOpacity,
        'enableShadow': _enableShadow,
        'position': _position,
        'initialPosition': 'center-top', // 设置初始位置为屏幕中上方
      });
      
      _isEnabled = true;
      _isVisible = true;
      
      // 如果有当前歌曲信息，立即更新
      if (_currentSongTitle.isNotEmpty) {
        await updateSongInfo(_currentSongTitle, _currentArtist);
      }
      
      // 启动定时器更新歌词
      _startUpdateTimer();
      
      print('桌面悬浮歌词已启用');
      _notifyStateChanged();
    } catch (e) {
      print('启用桌面悬浮歌词失败: $e');
    }
  }

  /// 禁用桌面悬浮歌词
  Future<void> disable() async {
    if (!_isEnabled) return;

    try {
      _stopUpdateTimer();
      await _channel.invokeMethod('disableDesktopLyrics');
      _isEnabled = false;
      _isVisible = false;
      _clearCurrentLyric();
      
      print('桌面悬浮歌词已禁用');
      _notifyStateChanged();
    } catch (e) {
      print('禁用桌面悬浮歌词失败: $e');
    }
  }

  /// 更新歌词数据
  void updateLyrics(List<LyricLine> lyrics) {
    _lyrics = lyrics;
    _currentLyricIndex = -1;
    
    if (_isEnabled && lyrics.isNotEmpty) {
      // 立即更新当前位置的歌词
      updatePosition(_currentPosition);
    }
  }

  /// 更新播放位置
  void updatePosition(Duration position) {
    _currentPosition = position;
    
    if (!_isEnabled || _lyrics.isEmpty) return;

    // 查找当前时间对应的歌词
    int newIndex = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].timestamp <= position) {
        // 检查是否在下一句歌词开始之前
        if (i + 1 < _lyrics.length) {
          if (_lyrics[i + 1].timestamp > position) {
            newIndex = i;
            break;
          }
        } else {
          // 最后一句歌词
          newIndex = i;
        }
      } else {
        break;
      }
    }

    // 如果歌词索引发生变化，更新显示
    if (newIndex != _currentLyricIndex) {
      _currentLyricIndex = newIndex;
      if (newIndex >= 0 && newIndex < _lyrics.length) {
        final lyricLine = _lyrics[newIndex];
        final lyricText = lyricLine.texts.isNotEmpty 
            ? lyricLine.texts.first 
            : '';
        _setCurrentLyric(lyricText);
      } else {
        _setCurrentLyric('');
      }
    }
  }

  /// 设置当前歌词
  void _setCurrentLyric(String lyric) {
    if (_currentLyric != lyric) {
      _currentLyric = lyric;
      _updateDesktopLyricsText(lyric);
      _notifyStateChanged();
    }
  }

  /// 更新歌曲信息
  Future<void> updateSongInfo(String title, String artist) async {
    _currentSongTitle = title;
    _currentArtist = artist;
    
    if (_isEnabled) {
      try {
        await _channel.invokeMethod('updateDesktopLyricsSongInfo', {
          'title': title,
          'artist': artist,
        });
      } catch (e) {
        print('更新桌面歌词歌曲信息失败: $e');
      }
    }
  }

  /// 更新桌面悬浮歌词文本
  Future<void> _updateDesktopLyricsText(String text) async {
    if (!_isEnabled) return;

    try {
      // 限制歌词长度，避免显示过长
      String displayText = text.length > 100 ? '${text.substring(0, 100)}...' : text;
      
      await _channel.invokeMethod('updateDesktopLyrics', {
        'text': displayText,
      });
    } catch (e) {
      print('更新桌面悬浮歌词文本失败: $e');
    }
  }

  /// 清除当前歌词
  void _clearCurrentLyric() {
    _setCurrentLyric('');
  }

  /// 清除桌面悬浮歌词
  Future<void> _clearDesktopLyrics() async {
    await _updateDesktopLyricsText('');
  }

  /// 设置可见性
  Future<void> setVisible(bool visible) async {
    if (!_isEnabled || _isVisible == visible) return;

    try {
      await _channel.invokeMethod('setDesktopLyricsVisible', {
        'visible': visible,
      });
      _isVisible = visible;
      _notifyStateChanged();
    } catch (e) {
      print('设置桌面悬浮歌词可见性失败: $e');
    }
  }

  /// 从设置提供者更新颜色配置
  Future<void> updateFromSettings() async {
    if (_settingsProvider != null && _isEnabled) {
      await updateStyle(
        fontSize: _settingsProvider!.desktopLyricsFontSize,
        fontColor: '#${_settingsProvider!.desktopLyricsTextColor.value.toRadixString(16).padLeft(8, '0')}',
        backgroundColor: '#${_settingsProvider!.desktopLyricsBackgroundColor.value.toRadixString(16).padLeft(8, '0')}',
      );
    }
  }

  /// 更新样式配置
  Future<void> updateStyle({
    double? fontSize,
    String? fontColor,
    String? backgroundColor,
    double? windowOpacity,
    bool? enableShadow,
    String? position,
  }) async {
    bool needUpdate = false;
    
    if (fontSize != null && fontSize != _fontSize) {
      _fontSize = fontSize;
      needUpdate = true;
    }
    if (fontColor != null && fontColor != _fontColor) {
      _fontColor = fontColor;
      needUpdate = true;
    }
    if (backgroundColor != null && backgroundColor != _backgroundColor) {
      _backgroundColor = backgroundColor;
      needUpdate = true;
    }
    if (windowOpacity != null && windowOpacity != _windowOpacity) {
      _windowOpacity = windowOpacity;
      needUpdate = true;
    }
    if (enableShadow != null && enableShadow != _enableShadow) {
      _enableShadow = enableShadow;
      needUpdate = true;
    }
    if (position != null && position != _position) {
      _position = position;
      needUpdate = true;
    }

    if (needUpdate && _isEnabled) {
      try {
        await _channel.invokeMethod('updateDesktopLyricsStyle', {
          'fontSize': _fontSize,
          'fontColor': _fontColor,
          'backgroundColor': _backgroundColor,
          'windowOpacity': _windowOpacity,
          'enableShadow': _enableShadow,
          'position': _position,
        });
      } catch (e) {
        print('更新桌面悬浮歌词样式失败: $e');
      }
    }
  }

  /// 启动更新定时器
  void _startUpdateTimer() {
    _stopUpdateTimer();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // 定时器主要用于处理歌词同步，实际位置更新由播放器驱动
    });
  }

  /// 停止更新定时器
  void _stopUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// 释放资源
  void dispose() {
    _stopUpdateTimer();
    _onStateChanged = null;
  }
}