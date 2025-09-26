import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../page/playlist/playlist_models.dart';

class StatusBarLyricsManager {
  static const MethodChannel _channel = MethodChannel('macos_media_service');
  
  static StatusBarLyricsManager? _instance;
  static StatusBarLyricsManager get instance {
    _instance ??= StatusBarLyricsManager._internal();
    return _instance!;
  }

  StatusBarLyricsManager._internal() {
    // 监听来自原生端的回调
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // 状态栏相关
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
  
  // 歌曲信息
  String _currentSongTitle = '';
  String _currentArtist = '';

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isVisible => _isVisible;
  String get currentLyric => _currentLyric;
  List<LyricLine> get lyrics => _lyrics;
  int get currentLyricIndex => _currentLyricIndex;
  String get currentSongTitle => _currentSongTitle;
  String get currentArtist => _currentArtist;

  /// 处理来自原生端的方法调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStatusBarLyricsDisabled':
        // 用户从状态栏菜单中禁用了歌词显示
        _isEnabled = false;
        _notifyStateChanged();
        break;
    }
  }

  /// 设置状态变化回调
  void setOnStateChanged(Function()? callback) {
    _onStateChanged = callback;
  }

  /// 通知状态变化
  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 初始化状态栏歌词功能
  Future<bool> initialize() async {
    if (!Platform.isMacOS) {
      print('状态栏歌词功能仅支持 macOS');
      return false;
    }

    try {
      print('状态栏歌词管理器初始化成功');
      return true;
    } catch (e) {
      print('状态栏歌词管理器初始化失败: $e');
      return false;
    }
  }

  /// 启用状态栏歌词
  Future<void> enable() async {
    if (!Platform.isMacOS || _isEnabled) return;

    try {
      if (!await initialize()) {
        return;
      }

      await _channel.invokeMethod('enableStatusBarLyrics');
      _isEnabled = true;
      _isVisible = true;
      
      // 如果有当前歌曲信息，立即更新
      if (_currentSongTitle.isNotEmpty) {
        await updateSongInfo(_currentSongTitle, _currentArtist);
      }
      if (_currentLyric.isNotEmpty) {
        await _updateStatusBarText(_currentLyric);
      } else {
        // 设置初始文本
        await _updateStatusBarText('♪ 暂无歌词');
      }
      
      // 启动更新定时器
      _startUpdateTimer();
      
      print('状态栏歌词已启用');
      _notifyStateChanged();
    } catch (e) {
      print('启用状态栏歌词失败: $e');
    }
  }

  /// 禁用状态栏歌词
  Future<void> disable() async {
    if (!_isEnabled) return;

    _stopUpdateTimer();
    
    try {
      await _channel.invokeMethod('disableStatusBarLyrics');
    } catch (e) {
      print('调用原生禁用方法失败: $e');
    }
    
    // 清除状态栏文本
    await _clearStatusBar();
    
    _isEnabled = false;
    _isVisible = false;
    _currentLyric = '';
    
    print('状态栏歌词已禁用');
    _notifyStateChanged();
  }

  /// 更新歌词数据
  void updateLyrics(List<LyricLine> lyrics) {
    _lyrics = lyrics;
    _currentLyricIndex = -1;
    
    if (_isEnabled) {
      _updateCurrentLyric();
    }
  }

  /// 更新播放位置
  void updatePosition(Duration position) {
    _currentPosition = position;
    
    if (_isEnabled && _lyrics.isNotEmpty) {
      _updateCurrentLyric();
    }
  }

  /// 显示/隐藏状态栏歌词
  void setVisible(bool visible) {
    if (_isVisible == visible) return;
    
    _isVisible = visible;
    
    if (_isEnabled) {
      if (visible) {
        _updateCurrentLyric();
      } else {
        _clearStatusBar();
      }
    }
    
    _notifyStateChanged();
  }

  /// 启动更新定时器
  void _startUpdateTimer() {
    _stopUpdateTimer();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isEnabled && _isVisible && _lyrics.isNotEmpty) {
        _updateCurrentLyric();
      }
    });
  }

  /// 停止更新定时器
  void _stopUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// 更新当前歌词
  void _updateCurrentLyric() {
    if (_lyrics.isEmpty) {
      _setCurrentLyric('♪ 暂无歌词');
      return;
    }

    // 查找当前时间对应的歌词
    int newIndex = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_currentPosition >= _lyrics[i].timestamp) {
        newIndex = i;
      } else {
        break;
      }
    }

    // 如果歌词索引发生变化，更新显示
    if (newIndex != _currentLyricIndex) {
      _currentLyricIndex = newIndex;
      
      if (newIndex >= 0 && newIndex < _lyrics.length) {
        final lyricLine = _lyrics[newIndex];
        
        // 状态栏歌词只显示第一行，确保处理逻辑稳定
        String lyricText = '';
        if (lyricLine.texts.isNotEmpty) {
          // 获取第一行歌词文本
          lyricText = lyricLine.texts.first.trim();
          
          // 如果第一行为空，尝试获取第一个非空行
          if (lyricText.isEmpty && lyricLine.texts.length > 1) {
            for (String text in lyricLine.texts) {
              final trimmedText = text.trim();
              if (trimmedText.isNotEmpty) {
                lyricText = trimmedText;
                break;
              }
            }
          }
        }
        
        if (lyricText.isNotEmpty) {
          _setCurrentLyric('♪ $lyricText');
        } else {
          _setCurrentLyric('♪ ...');
        }
      } else {
        _setCurrentLyric('♪ 暂无歌词');
      }
    }
  }

  /// 设置当前歌词文本
  void _setCurrentLyric(String lyric) {
    if (_currentLyric == lyric) return;
    
    _currentLyric = lyric;
    
    if (_isEnabled && _isVisible) {
      _updateStatusBarText(lyric);
    }
    
    _notifyStateChanged();
  }

  /// 更新歌曲信息
  Future<void> updateSongInfo(String title, String artist) async {
    try {
      _currentSongTitle = title;
      _currentArtist = artist;
      if (_isEnabled) {
        await _channel.invokeMethod('updateSongInfo', {
          'title': title,
          'artist': artist,
        });
        print('状态栏歌曲信息已更新: $title - $artist');
      }
    } catch (e) {
      print('更新状态栏歌曲信息失败: $e');
    }
  }

  /// 更新状态栏文本 (使用原生方法)
  Future<void> _updateStatusBarText(String text) async {
    if (!_isEnabled) return;

    try {
      // 限制文本长度，避免状态栏过长
      String displayText = text;
      if (displayText.length > 50) {
        displayText = '${displayText.substring(0, 47)}...';
      }
      
      await _channel.invokeMethod('updateStatusBarLyrics', {
        'lyrics': displayText,
      });
      print('状态栏歌词: $displayText');
      
    } catch (e) {
      print('更新状态栏文本失败: $e');
    }
  }

  /// 清除状态栏
  Future<void> _clearStatusBar() async {
    try {
      if (_isEnabled) {
        await _channel.invokeMethod('updateStatusBarLyrics', {
          'lyrics': '',
        });
      }
      print('清除状态栏歌词');
    } catch (e) {
      print('清除状态栏失败: $e');
    }
  }

  /// 清理资源
  void dispose() {
    disable();
    _stopUpdateTimer();
  }
}