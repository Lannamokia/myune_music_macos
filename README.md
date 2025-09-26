# Myune Music

一个基于 **Flutter (Dart)** 实现的现代化跨平台本地音乐播放器。

> 🙏 **致谢原作者**  
> 本项目基于 [xiaobaimc/myune_music](https://github.com/xiaobaimc/myune_music) 进行修改和增强。  
> 感谢原作者 **xiaobaimc** 的开源贡献，为我们提供了优秀的基础代码！

## ✨ 特性

### 🎵 核心功能
* 🎶 支持多种 **本地音频格式**，自动读取 **音频元数据**
* 📝 **智能歌词显示**：支持本地 `.lrc` 文件、音频文件 **内嵌歌词** 及 **网络歌词获取**
* 🎚️ **高级音频控制**：音调调节、倍速播放、音量控制
* 📁 **灵活的音乐管理**：歌单管理、文件夹导入、按歌手/专辑自动分类

### 🎨 界面与体验
* 🎨 采用 [**Material 3**](https://m3.material.io/) 设计语言
* 🌈 **自定义主题配色** 与 **字体选择**
* 🖥️ **悬浮歌词窗口**：支持实时歌词显示，可自定义样式和位置
* 📊 **状态栏歌词**：在系统状态栏显示当前歌词

### 🖥️ 平台支持
* 💻 **macOS**：完整功能支持，包括原生媒体控制
* 🪟 **Windows**：支持 SMTC（系统媒体传输控制）、音频独占播放
* 🐧 **Linux**：支持 MPRIS 协议

### 🎛️ 系统集成
* 🎮 **系统媒体控制**：支持键盘媒体键、通知中心控制
* 🔊 **音频设备管理**：手动选择音频输出设备
* ⌨️ **全局快捷键**：支持系统级快捷键控制

## 🌐 关于网络歌词获取

启用后，将在未读取到**内联歌词**和本地 `.lrc` 文件自动获取歌词

实现参考 [通过歌曲名获取原文+翻译歌词](https://www.showby.top/archives/624)

## 🔧 平台特定说明

### 🍎 macOS
* ✅ **完整功能支持**：悬浮歌词、状态栏歌词、原生媒体控制
* ✅ **系统集成**：支持媒体键、通知中心控制
* ✅ **原生体验**：完全适配 macOS 设计规范

### 🐧 Linux
* 📍 **测试环境**：Debian 12 + Gnome(X11)
* ⚠️ **已知问题**：无法选择字体
* 🔧 **依赖要求**：需要安装 `libmpv`

#### Linux 依赖安装

**Ubuntu/Debian**
```bash
sudo apt install libmpv-dev mpv 
```

**Fedora/RHEL**
```bash
sudo dnf install mpv-devel mpv
```

**Arch Linux**
```bash
sudo pacman -S mpv
```

## 📸 项目截图
![](screenshot/0ed4c6045d9d5ec7ffbb1e2d37fbc082.png)
![](screenshot/80b1797d1eeffb5e676c999e9111c29e.png)
![](screenshot/b9c1ea02a032da463abe86ec6fbedbe4.png) 
![](screenshot/8525ee8949583b6648132a43849dbab3.png)
![](screenshot/a55adee800e474ac31f5ea79a36f2a57.png)
![](screenshot/43b5446daf9a740ea7cf7b596f2bad1f.png)
![](screenshot/8ee8249892e86a396a181306406e3a9d.png) 

## 🚀 快速开始

### 📋 环境要求

* **Flutter SDK** ≥ 3.8.0
* **Dart SDK** ≥ 3.8.0  
* **Rust** 工具链（用于 Rust 桥接）

#### 平台特定要求

**macOS**
* Xcode 14.0+
* macOS 10.14+

**Windows**
* Visual Studio 2022 或 Visual Studio Build Tools
* Windows 10+

**Linux**
* GCC 编译器
* 相关开发库（见上方依赖安装）

### 🔧 安装与构建

1. **克隆项目**
```bash
git clone <repository-url>
cd myune_music
```

2. **安装 Flutter 依赖**
```bash
flutter pub get
```

3. **运行项目**
```bash
# 开发模式
flutter run

# 或指定平台
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

4. **构建发布版本**
```bash
# macOS
flutter build macos --release

# Windows  
flutter build windows --release

# Linux
flutter build linux --release
```

## 📦 主要依赖与致谢

### 🔧 核心依赖
* [**media_kit**](https://pub.dev/packages/media_kit) - 强大的跨平台音频播放引擎
* [**audio_metadata_reader**](https://pub.dev/packages/audio_metadata_reader) - 音频元数据读取
* [**flutter_rust_bridge**](https://pub.dev/packages/flutter_rust_bridge) - Flutter 与 Rust 桥接
* [**provider**](https://pub.dev/packages/provider) - 状态管理
* [**shared_preferences**](https://pub.dev/packages/shared_preferences) - 本地存储

### 🖥️ 平台特定
* [**anni_mpris_service**](https://pub.dev/packages/anni_mpris_service) - Linux MPRIS 协议支持
* [**window_manager**](https://pub.dev/packages/window_manager) - 窗口管理
* [**system_fonts**](https://pub.dev/packages/system_fonts) - 系统字体获取

### 🎨 UI 组件
* [**flutter_colorpicker**](https://pub.dev/packages/flutter_colorpicker) - 颜色选择器
* [**scrollable_positioned_list**](https://pub.dev/packages/scrollable_positioned_list) - 可定位滚动列表

> 📄 完整依赖列表请查看 [pubspec.yaml](pubspec.yaml)

### 🙏 特别致谢

* [**xiaobaimc**](https://github.com/xiaobaimc/myune_music) - 原项目作者，提供了优秀的基础代码
* [**爱情终是残念**](https://aqzscn.cn/archives/flutter-smtc) - SMTC 实现参考
* [**Ferry-200**](https://github.com/Ferry-200/coriander_player) - Rust + Flutter 架构参考
* [**小米公司**](https://hyperos.mi.com/font/) - MiSans 字体支持
* 所有开源项目的贡献者们 ❤️

## 🔄 本分支改进

基于原项目 [xiaobaimc/myune_music](https://github.com/xiaobaimc/myune_music)，本分支主要进行了以下改进：

### 🍎 macOS 平台增强
* ✅ **完整 macOS 支持**：从原来的 Windows/Linux 双端扩展到三端支持
* ✅ **悬浮歌词窗口**：全新实现的桌面悬浮歌词功能
* ✅ **状态栏歌词**：在 macOS 状态栏显示当前歌词
* ✅ **原生媒体控制**：完整的 macOS 媒体键和通知中心集成

### 🎵 歌词功能优化
* ✅ **实时歌词更新**：修复悬浮歌词不实时更新的问题
* ✅ **自适应窗口**：悬浮歌词窗口根据内容自动调整大小
* ✅ **位置记忆**：记住用户设置的悬浮窗口位置
* ✅ **样式自定义**：支持字体、颜色、背景等完全自定义

### 🔧 技术架构改进
* ✅ **Swift 原生插件**：为 macOS 开发专用的原生媒体服务插件
* ✅ **状态管理优化**：改进歌词显示的状态同步机制
* ✅ **性能优化**：优化定时器和内存使用

## 📈 版本信息

当前版本：**v0.6.4**

### 🆕 最新更新
* ✅ 修复悬浮歌词实时更新问题
* ✅ 优化关闭按钮位置自适应逻辑
* ✅ 改进状态栏歌词显示
* ✅ 增强 macOS 平台兼容性

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 🐛 报告问题
* 使用 [GitHub Issues](../../issues) 报告 Bug
* 请详细描述问题复现步骤
* 提供系统环境信息

### 💡 功能建议
* 在 Issues 中提出新功能建议
* 说明功能的使用场景和预期效果

### 🔧 代码贡献
1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目使用 **Apache License 2.0** 开源许可协议。
详细内容请查看根目录下的 [LICENSE](/LICENSE) 文件。

## 🔤 字体版权说明（Font License）

本项目使用小米公司提供的 **MiSans 字体**，该字体已明确允许**免费商用**。

* 字体版权归小米公司所有
* 相关许可协议请查阅：[MiSans 字体知识产权使用许可协议](https://hyperos.mi.com/font-download/MiSans%E5%AD%97%E4%BD%93%E7%9F%A5%E8%AF%86%E4%BA%A7%E6%9D%83%E8%AE%B8%E5%8F%AF%E5%8D%8F%E8%AE%AE.pdf)
* MiSans 官网：[https://hyperos.mi.com/font/](https://hyperos.mi.com/font/)
