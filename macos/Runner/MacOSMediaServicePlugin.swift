import Cocoa
import FlutterMacOS
import MediaPlayer

public class MacOSMediaServicePlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var nowPlayingInfo: [String: Any] = [:]
    
    // 状态栏歌词相关
    private var statusItem: NSStatusItem?
    private var statusBarLyricsEnabled = false
    private var currentLyrics = ""
    private var currentSongTitle = ""
    private var currentArtist = ""
    
    // 桌面悬浮歌词相关
    private var desktopLyricsWindow: NSWindow?
    private var desktopLyricsLabel: NSTextField?
    private var desktopLyricsEnabled = false
    private var desktopLyricsStyle: [String: Any] = [:]
    private var playPauseButton: NSButton?
    private var isPlaying = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "macos_media_service", binaryMessenger: registrar.messenger)
        let instance = MacOSMediaServicePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(result: result)
        case "updateMetadata":
            updateMetadata(call: call, result: result)
        case "updateState":
            updateState(call: call, result: result)
        case "updateTimeline":
            updateTimeline(call: call, result: result)
        case "dispose":
            dispose(result: result)
        case "enableStatusBarLyrics":
            enableStatusBarLyrics(result: result)
        case "disableStatusBarLyrics":
            disableStatusBarLyrics(result: result)
        case "updateStatusBarLyrics":
            updateStatusBarLyrics(call: call, result: result)
        case "updateSongInfo":
            updateSongInfo(call: call, result: result)
        case "enableDesktopLyrics":
            enableDesktopLyrics(call: call, result: result)
        case "disableDesktopLyrics":
            disableDesktopLyrics(result: result)
        case "updateDesktopLyrics":
            updateDesktopLyrics(call: call, result: result)
        case "updateDesktopLyricsStyle":
            updateDesktopLyricsStyle(call: call, result: result)
        case "updateDesktopLyricsSongInfo":
            updateDesktopLyricsSongInfo(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initialize(result: @escaping FlutterResult) {
        // 设置远程控制事件监听
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.channel?.invokeMethod("onPlay", arguments: nil)
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.channel?.invokeMethod("onPause", arguments: nil)
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.channel?.invokeMethod("onNext", arguments: nil)
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.channel?.invokeMethod("onPrevious", arguments: nil)
            return .success
        }
        
        // 启用命令
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        
        result(nil)
    }
    
    private func updateMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        let title = args["title"] as? String ?? ""
        let artist = args["artist"] as? String ?? ""
        let album = args["album"] as? String ?? ""
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        
        // 处理专辑封面
        if let albumArtData = args["albumArt"] as? FlutterStandardTypedData,
           let image = NSImage(data: albumArtData.data) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        result(nil)
    }
    
    private func updateState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let isPlaying = args["isPlaying"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        // 更新播放状态
        self.isPlaying = isPlaying
        
        // 更新悬浮歌词窗口中的播放/暂停按钮
        updatePlayPauseButton()
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        result(nil)
    }
    
    private func updateTimeline(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let position = args["position"] as? Int,
              let duration = args["duration"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(position) / 1000.0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(duration) / 1000.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        result(nil)
    }
    
    private func dispose(result: @escaping FlutterResult) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // 清理状态栏项目
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        
        // 清理桌面悬浮歌词窗口
        if let window = desktopLyricsWindow {
            window.close()
            self.desktopLyricsWindow = nil
            self.desktopLyricsLabel = nil
        }
        
        result(nil)
    }
    
    // MARK: - 状态栏歌词相关方法
    
    private func enableStatusBarLyrics(result: @escaping FlutterResult) {
        statusBarLyricsEnabled = true
        
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.button?.title = "♪ 暂无歌词"
            
            // 创建菜单
            let menu = NSMenu()
            let songInfoItem = NSMenuItem(title: "暂无播放", action: nil, keyEquivalent: "")
            songInfoItem.isEnabled = false
            menu.addItem(songInfoItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let quitItem = NSMenuItem(title: "隐藏歌词", action: #selector(hideStatusBarLyrics), keyEquivalent: "")
            quitItem.target = self
            menu.addItem(quitItem)
            
            statusItem?.menu = menu
        }
        
        updateStatusBarDisplay()
        result(nil)
    }
    
    private func disableStatusBarLyrics(result: @escaping FlutterResult) {
        statusBarLyricsEnabled = false
        
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        
        result(nil)
    }
    
    private func updateStatusBarLyrics(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lyrics = args["lyrics"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        currentLyrics = lyrics
        updateStatusBarDisplay()
        result(nil)
    }
    
    private func updateSongInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String,
              let artist = args["artist"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        currentSongTitle = title
        currentArtist = artist
        updateStatusBarDisplay()
        result(nil)
    }
    
    private func updateStatusBarDisplay() {
        guard statusBarLyricsEnabled, let statusItem = statusItem else { return }
        
        DispatchQueue.main.async {
            if self.currentLyrics.isEmpty {
                if self.currentSongTitle.isEmpty {
                    statusItem.button?.title = "♪ 暂无歌词"
                } else {
                    statusItem.button?.title = "♪ \(self.currentSongTitle)"
                }
            } else {
                // 限制歌词长度，避免状态栏过长
                let maxLength = 50
                let displayLyrics = self.currentLyrics.count > maxLength 
                    ? String(self.currentLyrics.prefix(maxLength)) + "..."
                    : self.currentLyrics
                statusItem.button?.title = "♪ \(displayLyrics)"
            }
            
            // 更新菜单中的歌曲信息
            if let menu = statusItem.menu, menu.items.count > 0 {
                let songInfo = self.currentSongTitle.isEmpty ? "暂无播放" : "\(self.currentSongTitle) - \(self.currentArtist)"
                menu.items[0].title = songInfo
            }
        }
    }
    
    @objc private func hideStatusBarLyrics() {
        channel?.invokeMethod("onStatusBarLyricsDisabled", arguments: nil)
    }
    
    // MARK: - 桌面悬浮歌词相关方法
    
    private func enableDesktopLyrics(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        desktopLyricsEnabled = true
        desktopLyricsStyle = args
        
        createDesktopLyricsWindow()
        result(nil)
    }
    
    private func disableDesktopLyrics(result: @escaping FlutterResult) {
        desktopLyricsEnabled = false
        
        if let window = desktopLyricsWindow {
            window.close()
            self.desktopLyricsWindow = nil
            self.desktopLyricsLabel = nil
        }
        
        result(nil)
    }
    
    private func updateDesktopLyrics(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        currentLyrics = text
        updateDesktopLyricsDisplay()
        result(nil)
    }
    
    private func updateDesktopLyricsStyle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        desktopLyricsStyle = args
        updateDesktopLyricsDisplay()
        result(nil)
    }
    
    private func updateDesktopLyricsSongInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        if let title = args["title"] as? String {
            currentSongTitle = title
        }
        if let artist = args["artist"] as? String {
            currentArtist = artist
        }
        
        result(nil)
    }
    
    private func createDesktopLyricsWindow() {
        // 获取屏幕尺寸
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // 获取样式配置
        let fontSize = desktopLyricsStyle["fontSize"] as? Double ?? 24.0
        let fontColor = desktopLyricsStyle["fontColor"] as? String ?? "#FFFFFF"
        let backgroundColor = desktopLyricsStyle["backgroundColor"] as? String ?? "#80000000"
        let _ = desktopLyricsStyle["initialPosition"] as? String ?? "center-top"
        
        // 计算初始位置：屏幕水平居中，顶部距离上边界10%
        let windowWidth: Double = 500
        let windowHeight: Double = 80
        let x = (screenFrame.width - windowWidth) / 2
        let y = screenFrame.height * 0.9 - windowHeight // 距离顶部10%
        
        // 创建窗口 - 增加宽度以容纳控制按钮
        let windowFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口属性
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // 关键：设置窗口不参与应用程序的窗口计数，防止关闭时导致程序退出
        window.hidesOnDeactivate = false
        window.canHide = false
        window.isExcludedFromWindowsMenu = true
        
        // 创建背景视图
        let backgroundView = NSView(frame: window.contentView!.bounds)
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = hexToNSColor(backgroundColor).cgColor
        backgroundView.layer?.cornerRadius = 8
        
        // 创建歌词标签
        let label = NSTextField(frame: NSRect(x: 10, y: 40, width: 480, height: 30))
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = NSColor.clear
        label.textColor = hexToNSColor(fontColor)
        label.font = NSFont.systemFont(ofSize: fontSize)
        label.alignment = .center
        label.stringValue = currentLyrics.isEmpty ? "♪ 暂无歌词" : currentLyrics
        
        // 创建控制按钮容器
        let controlsView = NSView(frame: NSRect(x: 0, y: 5, width: 500, height: 30))
        
        // 上一曲按钮
        let prevButton = NSButton(frame: NSRect(x: 150, y: 0, width: 30, height: 30))
        prevButton.title = "⏮"
        prevButton.bezelStyle = .circular
        prevButton.target = self
        prevButton.action = #selector(previousTrack)
        
        // 播放/暂停按钮
        let playPauseButton = NSButton(frame: NSRect(x: 190, y: 0, width: 30, height: 30))
        playPauseButton.title = isPlaying ? "⏸" : "▶"
        playPauseButton.bezelStyle = .circular
        playPauseButton.target = self
        playPauseButton.action = #selector(togglePlayPause)
        
        // 保存按钮引用
        self.playPauseButton = playPauseButton
        
        // 下一曲按钮
        let nextButton = NSButton(frame: NSRect(x: 230, y: 0, width: 30, height: 30))
        nextButton.title = "⏭"
        nextButton.bezelStyle = .circular
        nextButton.target = self
        nextButton.action = #selector(nextTrack)
        
        // 关闭按钮
        let closeButton = NSButton(frame: NSRect(x: 460, y: 0, width: 30, height: 30))
        closeButton.title = "✕"
        closeButton.bezelStyle = .circular
        closeButton.target = self
        closeButton.action = #selector(closeDesktopLyrics)
        
        controlsView.addSubview(prevButton)
        controlsView.addSubview(playPauseButton)
        controlsView.addSubview(nextButton)
        controlsView.addSubview(closeButton)
        
        backgroundView.addSubview(label)
        backgroundView.addSubview(controlsView)
        window.contentView = backgroundView
        
        // 添加拖拽功能
        let dragGesture = NSPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        backgroundView.addGestureRecognizer(dragGesture)
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        
        self.desktopLyricsWindow = window
        self.desktopLyricsLabel = label
    }
    
    private func updateDesktopLyricsDisplay() {
        guard desktopLyricsEnabled, let label = desktopLyricsLabel else { return }
        
        DispatchQueue.main.async {
            let displayText = self.currentLyrics.isEmpty ? "♪ 暂无歌词" : self.currentLyrics
            label.stringValue = displayText
            
            // 更新样式
            if let fontSize = self.desktopLyricsStyle["fontSize"] as? Double {
                label.font = NSFont.systemFont(ofSize: fontSize)
            }
            if let fontColor = self.desktopLyricsStyle["fontColor"] as? String {
                label.textColor = self.hexToNSColor(fontColor)
            }
            if let backgroundColor = self.desktopLyricsStyle["backgroundColor"] as? String,
               let backgroundView = label.superview {
                backgroundView.layer?.backgroundColor = self.hexToNSColor(backgroundColor).cgColor
            }
        }
    }
    
    @objc private func handleDrag(_ gesture: NSPanGestureRecognizer) {
        guard let window = desktopLyricsWindow else { return }
        
        switch gesture.state {
        case .began:
            // 记录拖动开始时的窗口位置
            break
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            let newOrigin = NSPoint(
                x: window.frame.origin.x + translation.x,
                y: window.frame.origin.y + translation.y // 修正Y轴方向，使其跟随鼠标移动
            )
            
            window.setFrameOrigin(newOrigin)
            gesture.setTranslation(.zero, in: gesture.view)
        case .ended, .cancelled:
            // 保存最终位置
            let finalOrigin = window.frame.origin
            channel?.invokeMethod("onDesktopLyricsPositionChanged", arguments: [
                "x": finalOrigin.x,
                "y": finalOrigin.y
            ])
        default:
            break
        }
    }
    
    // 媒体控制按钮动作方法
    @objc private func previousTrack() {
        channel?.invokeMethod("onPrevious", arguments: nil)
    }
    
    @objc private func togglePlayPause() {
        channel?.invokeMethod("onTogglePlayPause", arguments: nil)
    }
    
    @objc private func nextTrack() {
        channel?.invokeMethod("onNext", arguments: nil)
    }
    
    @objc private func closeDesktopLyrics() {
        // 安全地关闭悬浮歌词窗口
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = self.desktopLyricsWindow {
                // 先隐藏窗口
                window.orderOut(nil)
                // 清理引用
                self.desktopLyricsWindow = nil
                self.desktopLyricsLabel = nil
                self.playPauseButton = nil
            }
            
            self.desktopLyricsEnabled = false
            
            // 通知 Flutter 端悬浮歌词已被关闭
            self.channel?.invokeMethod("onDesktopLyricsDisabled", arguments: nil)
        }
    }
    
    private func updatePlayPauseButton() {
        guard let button = playPauseButton else { return }
        
        DispatchQueue.main.async {
            button.title = self.isPlaying ? "⏸" : "▶"
        }
    }
    
    private func hexToNSColor(_ hex: String) -> NSColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        var alpha: CGFloat = 1.0
        
        if hexSanitized.count == 8 {
            // ARGB格式
            Scanner(string: hexSanitized).scanHexInt64(&rgb)
            alpha = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            rgb = rgb & 0x00FFFFFF
        } else if hexSanitized.count == 6 {
            // RGB格式
            Scanner(string: hexSanitized).scanHexInt64(&rgb)
        } else {
            return NSColor.white
        }
        
        return NSColor(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: alpha
        )
    }
}