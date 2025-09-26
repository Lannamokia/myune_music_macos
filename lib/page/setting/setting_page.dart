import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../playlist/playlist_content_notifier.dart';
import './theme_selection_screen.dart';
import '../../theme/theme_provider.dart';
import './settings_provider.dart';
import '../../widgets/font_selector_row.dart';
import 'update_checker.dart';
import 'audio_device_selector.dart';
import '../../services/desktop_lyrics_manager.dart';

// 定义应用版本号常量
const String appVersion = '0.6.4';

bool get isLinux => Platform.isLinux;

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _fontSelectorEnabled = false;
  final bool _isCheckingUpdate = false; // 是否正在检查更新
  final String _updateStatus = ''; // 更新状态信息

  @override
  void initState() {
    super.initState();
  }

  // 检查更新
  Future<void> _checkForUpdates() async {
    final notifier = context.read<PlaylistContentNotifier>();

    try {
      notifier.postInfo('正在检查更新...');

      // 使用写好的版本号
      final result = await UpdateChecker.checkForUpdates(appVersion);

      switch (result.type) {
        case UpdateCheckResultType.successUpdateAvailable:
          notifier.postInfo('发现新版本 ${result.updateInfo!.latestVersion}');
          _showUpdateDialog(result.updateInfo!);
          break;
        case UpdateCheckResultType.successNoUpdate:
          notifier.postInfo('当前已是最新版本');
          break;
        case UpdateCheckResultType.error:
          notifier.postError('检查更新失败: ${result.errorMessage}');
          break;
      }
    } catch (e) {
      notifier.postError('检查更新失败: ${e.toString()}');
    }
  }

  // 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('发现新版本 ${updateInfo.latestVersion}'),
          content: SingleChildScrollView(child: Text(updateInfo.releaseNotes)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('稍后更新'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (await canLaunchUrl(Uri.parse(updateInfo.downloadUrl))) {
                  await launchUrl(Uri.parse(updateInfo.downloadUrl));
                }
              },
              child: const Text('前往下载'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用 watch 来监听 SettingsProvider 的变化
    final settings = context.watch<SettingsProvider>();

    return ListView(
      children: [
        // 主题配色选择
        const ThemeSelectionScreen(),
        // 检查更新按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '当前版本: $appVersion',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ElevatedButton.icon(
                onPressed: _checkForUpdates,
                icon: _isCheckingUpdate
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.update, size: 20),
                label: const Text('检查更新'),
              ),
            ],
          ),
        ),
        if (_updateStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _updateStatus,
              style: TextStyle(
                color: _updateStatus.contains('失败')
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        // 音频设备选择
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '手动指定音频输出设备',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return const AudioDeviceSelector();
                    },
                  );
                },
                icon: const Icon(Icons.headphones, size: 20),
                label: const Text('选择设备'),
              ),
            ],
          ),
        ),
        // 独占模式设置
        if (!isLinux) // 仅在非Linux平台显示
          Consumer<PlaylistContentNotifier>(
            builder: (context, playlistNotifier, child) {
              return SwitchListTile(
                title: const Row(
                  children: [
                    Text('启用独占模式'),
                    SizedBox(width: 4),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      icon: Icon(Icons.info_outline, size: 20),
                      tooltip:
                          '启用后将使用独占模式播放音频，提供更低的延迟以及更好的音质\n这可能会导致其他应用无法播放音频\n仅在播放器处于活跃状态时可用',
                      onPressed: null,
                    ),
                  ],
                ),
                value: playlistNotifier.isExclusiveModeEnabled,
                onChanged: playlistNotifier.toggleExclusiveMode,
              );
            },
          ),
        // 允许添加任何格式的文件
        SwitchListTile(
          title: const Row(
            children: [
              Text('允许添加任何格式的文件'),
              SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.info_outline, size: 20),
                tooltip:
                    '启用后可以选择任何格式的文件添加到歌单中\n底层使用 mpv，依赖 FFmpeg 解码，理论上支持播放所有音频格式\n除非确认兼容性，否则请谨慎启用该选项',
                onPressed: null,
              ),
            ],
          ),
          value: settings.allowAnyFormat,
          onChanged: (value) {
            context.read<SettingsProvider>().setAllowAnyFormat(value);
          },
        ),
        // 启用动态获取颜色
        SwitchListTile(
          title: Text(
            '提取当前播放的封面图颜色作为主题配色',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          value: settings.useDynamicColor, // 使用 settings
          onChanged: (value) {
            context.read<SettingsProvider>().setUseDynamicColor(value);
            // 当启用动态颜色时，立即提取当前播放歌曲的封面颜色
            if (value) {
              final playlistNotifier = context.read<PlaylistContentNotifier>();
              final currentSong = playlistNotifier.currentSong;
              if (currentSong != null) {
                playlistNotifier.extractAndApplyDynamicColor(
                  currentSong.albumArt,
                );
              }
            }
            // 当关闭动态颜色时，恢复默认颜色
            if (!value) {
              context.read<ThemeProvider>().setSeedColor(Colors.blue);
            }
          },
        ),
        // 深色模式
        SwitchListTile(
          title: Text('深色模式', style: Theme.of(context).textTheme.titleMedium),
          value: context.watch<ThemeProvider>().isDarkMode,
          onChanged: (value) => context.read<ThemeProvider>().toggleDarkMode(),
        ),
        // 启用系统字体选择器
        SwitchListTile(
          title: Text(
            '启用系统字体选择器',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          value: _fontSelectorEnabled,
          onChanged: (value) {
            setState(() {
              _fontSelectorEnabled = value;
            });
          },
        ),
        // 系统字体选择器
        if (_fontSelectorEnabled)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FontSelectorRow(),
          ),
        // 启用模糊背景
        SwitchListTile(
          title: Text(
            '启用详情页模糊背景',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          value: settings.useBlurBackground, // 使用 settings
          onChanged: (value) {
            context.read<SettingsProvider>().setUseBlurBackground(value);
          },
        ),
        // 始终保持单行歌词显示
        SwitchListTile(
          title: Text(
            '顶部歌词始终单行显示',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          value: settings.forceSingleLineLyric,
          onChanged: (value) {
            context.read<SettingsProvider>().setForceSingleLineLyric(value);
          },
        ),
        // 歌词上下补位设置
        SwitchListTile(
          title: const Text('强制播放页高亮歌词垂直居中显示'),
          value: settings.addLyricPadding,
          onChanged: (value) {
            context.read<SettingsProvider>().setAddLyricPadding(value);
          },
        ),
        // 是否启用从网络获取歌词
        SwitchListTile(
          title: const Text('从网络获取歌词'),
          value: settings.enableOnlineLyrics,
          onChanged: (value) {
            context.read<SettingsProvider>().setEnableOnlineLyrics(value);
          },
        ),
        // 状态栏歌词开关
        if (Platform.isMacOS)
          SwitchListTile(
            title: const Row(
              children: [
                Text('启用状态栏歌词'),
                SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: Icon(Icons.info_outline, size: 20),
                  tooltip: '在macOS状态栏显示当前播放的歌词\n仅在macOS系统上可用',
                  onPressed: null,
                ),
              ],
            ),
            value: settings.enableStatusBarLyrics,
            onChanged: (value) {
              context.read<SettingsProvider>().setEnableStatusBarLyrics(value);
              
              // 启用或禁用状态栏歌词管理器
              final playlistNotifier = context.read<PlaylistContentNotifier>();
              if (playlistNotifier.statusBarLyricsManager != null) {
                if (value) {
                  playlistNotifier.statusBarLyricsManager!.enable();
                } else {
                  playlistNotifier.statusBarLyricsManager!.disable();
                }
              }
            },
          ),
        // 桌面悬浮歌词开关
        if (Platform.isMacOS)
          SwitchListTile(
            title: const Row(
              children: [
                Text('启用桌面悬浮歌词'),
                SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: Icon(Icons.info_outline, size: 20),
                  tooltip: '在桌面显示悬浮歌词窗口\n可拖拽移动位置，仅在macOS系统上可用',
                  onPressed: null,
                ),
              ],
            ),
            value: settings.enableDesktopLyrics,
            onChanged: (value) async {
              context.read<SettingsProvider>().setEnableDesktopLyrics(value);
              
              // 启用或禁用桌面悬浮歌词管理器
              final playlistNotifier = context.read<PlaylistContentNotifier>();
              if (playlistNotifier.desktopLyricsManager != null) {
                try {
                  if (value) {
                    await playlistNotifier.desktopLyricsManager!.enable(delaySeconds: 1);
                  } else {
                    await playlistNotifier.desktopLyricsManager!.disable();
                  }
                } catch (e) {
                  print('桌面悬浮歌词开关操作失败: $e');
                  // 如果操作失败，恢复设置状态
                  if (context.mounted) {
                    context.read<SettingsProvider>().setEnableDesktopLyrics(!value);
                  }
                }
              }
            },
          ),
        // 桌面悬浮歌词配置
        if (settings.enableDesktopLyrics) ...[
          // 文字颜色选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('悬浮歌词文字颜色', style: Theme.of(context).textTheme.titleMedium),
                GestureDetector(
                  onTap: () {
                    _showColorPicker(
                      context,
                      '选择文字颜色',
                      settings.desktopLyricsTextColor,
                      (color) {
                        context.read<SettingsProvider>().setDesktopLyricsTextColor(color);
                        // 更新桌面悬浮歌词管理器的颜色配置
                        DesktopLyricsManager.instance.updateFromSettings();
                      },
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: settings.desktopLyricsTextColor,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 背景颜色选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('悬浮歌词背景颜色', style: Theme.of(context).textTheme.titleMedium),
                GestureDetector(
                  onTap: () {
                    _showColorPicker(
                      context,
                      '选择背景颜色',
                      settings.desktopLyricsBackgroundColor,
                      (color) {
                        context.read<SettingsProvider>().setDesktopLyricsBackgroundColor(color);
                        // 更新桌面悬浮歌词管理器的颜色配置
                        DesktopLyricsManager.instance.updateFromSettings();
                      },
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: settings.desktopLyricsBackgroundColor,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 字体大小
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('悬浮歌词字体大小', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(
                  width: 320,
                  child: Slider(
                    value: settings.desktopLyricsFontSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 20,
                    label: '${settings.desktopLyricsFontSize.round()}',
                    onChanged: (value) {
                      context.read<SettingsProvider>().setDesktopLyricsFontSize(value);
                      // 更新桌面悬浮歌词管理器的字体大小配置
                      DesktopLyricsManager.instance.updateFromSettings();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        // 歌词源选择
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '网络歌词源选择',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 4),
                  const IconButton(
                    icon: Icon(Icons.info_outline, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    tooltip:
                        '主选来源为某易云音乐，备选来源为某狗音乐\n其中备选只有原文没有翻译，但歌词匹配可能会更精确\n当未启用从网络获取歌词时，该选项不会生效',
                    onPressed: null,
                  ),
                ],
              ),
              SegmentedButton<String>(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  visualDensity: VisualDensity.compact,
                  minimumSize: WidgetStateProperty.all(const Size(0, 0)),
                ),
                segments: const [
                  ButtonSegment(value: 'primary', label: Text('主选')),
                  ButtonSegment(value: 'secondary', label: Text('备选')),
                ],
                selected: {settings.primaryLyricSource},
                onSelectionChanged: (newSelection) {
                  if (newSelection.isNotEmpty) {
                    final selected = newSelection.first;
                    final secondary = selected == 'primary'
                        ? 'secondary'
                        : 'primary';
                    final settingsProvider = context.read<SettingsProvider>();

                    settingsProvider.setPrimaryLyricSource(selected);
                    settingsProvider.setSecondaryLyricSource(secondary);
                  }
                },
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
        // 详情页同时间戳最大显示歌词行数
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('同时间戳歌词行数', style: Theme.of(context).textTheme.titleMedium),
              SegmentedButton<int>(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  visualDensity: VisualDensity.compact,
                  minimumSize: WidgetStateProperty.all(const Size(0, 0)),
                ),
                segments: List.generate(5, (index) {
                  final value = index + 1;
                  return ButtonSegment(value: value, label: Text('$value'));
                }),
                selected: {settings.maxLinesPerLyric}, // 使用 settings
                onSelectionChanged: (newSelection) {
                  final value = newSelection.first;
                  context.read<SettingsProvider>().setMaxLinesPerLyric(value);
                },
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
        // 详情页歌词字体大小
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('详情页歌词字体大小', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(
                width: 320, // 固定宽度
                child: Slider(
                  value: settings.fontSize, // 使用 settings
                  min: 12.0,
                  max: 32.0,
                  divisions: 20,
                  label: settings.fontSize.toStringAsFixed(1), // 使用 settings
                  onChanged: (value) {
                    context.read<SettingsProvider>().setFontSize(value);
                  },
                ),
              ),
            ],
          ),
        ),
        // 对齐方式选择
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('详情页歌词对齐方式', style: Theme.of(context).textTheme.titleMedium),
              SegmentedButton<TextAlign>(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  visualDensity: VisualDensity.compact,
                  minimumSize: WidgetStateProperty.all(const Size(0, 0)),
                ),
                segments: const [
                  ButtonSegment(value: TextAlign.left, label: Text('居左')),
                  ButtonSegment(value: TextAlign.center, label: Text('居中')),
                  ButtonSegment(value: TextAlign.right, label: Text('居右')),
                ],
                selected: {settings.lyricAlignment}, // 使用 settings
                onSelectionChanged: (Set<TextAlign> newSelection) {
                  if (newSelection.isNotEmpty) {
                    context.read<SettingsProvider>().setLyricAlignment(
                      newSelection.first,
                    );
                  }
                },
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context, String title, Color currentColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color selectedColor = currentColor;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 预设颜色
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Colors.white,
                        Colors.black,
                        Colors.red,
                        Colors.green,
                        Colors.blue,
                        Colors.yellow,
                        Colors.orange,
                        Colors.purple,
                        Colors.pink,
                        Colors.cyan,
                        Colors.grey,
                        Colors.brown,
                        Colors.black54,
                        Colors.white70,
                        Colors.transparent,
                      ].map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              border: Border.all(
                                color: selectedColor == color ? Colors.blue : Colors.grey,
                                width: selectedColor == color ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: color == Colors.transparent
                                ? const Icon(Icons.block, color: Colors.red)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // 当前选择的颜色预览
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: selectedColor == Colors.transparent
                          ? const Center(child: Text('透明', style: TextStyle(color: Colors.black)))
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    onColorChanged(selectedColor);
                    Navigator.of(context).pop();
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
