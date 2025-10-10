import 'package:flutter/material.dart';

/// 显示歌词目录访问权限提醒对话框
/// 
/// 在打开文件夹选择器之前，先向用户说明需要授权歌词目录访问权限
Future<bool> showLyricsDirectoryPermissionDialog(BuildContext context, String directoryPath) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 不允许点击外部关闭
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_open, size: 24),
            SizedBox(width: 8),
            Text('歌词目录访问权限'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '由于歌词所在目录的访问权限未被取得，需要您授权访问以下目录：',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        directoryPath,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '接下来将打开文件夹选择器，请选择相关目录以授权访问权限。',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '这是为了加载歌词文件所必需的权限',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('打开文件夹选择器'),
          ),
        ],
      );
    },
  );
  
  // 如果对话框返回null（比如用户按了ESC键），默认返回false
  return result ?? false;
}