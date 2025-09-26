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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                result(nil)
                return 
            }
            
            // 清理 MPRemoteCommandCenter 的 target
            let commandCenter = MPRemoteCommandCenter.shared()
            commandCenter.playCommand.removeTarget(self)
            commandCenter.pauseCommand.removeTarget(self)
            commandCenter.nextTrackCommand.removeTarget(self)
            commandCenter.previousTrackCommand.removeTarget(self)
            
            // 清理 MPNowPlayingInfoCenter
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            
            // 清理状态栏项目
            if let statusItem = self.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            
            // 清理桌面歌词窗口
            if let window = self.desktopLyricsWindow {
                // 清理手势识别器
                if let contentView = window.contentView {
                    contentView.gestureRecognizers.forEach { recognizer in
                        contentView.removeGestureRecognizer(recognizer)
                    }
                }
                
                // 清理按钮目标引用
                self.clearButtonTargets(in: window.contentView)
                
                // 使用 orderOut 而不是 close
                window.orderOut(nil)
                
                // 清理引用
                self.desktopLyricsWindow = nil
                self.desktopLyricsLabel = nil
                self.playPauseButton = nil
            }
            
            // 清理其他状态
            self.statusBarLyricsEnabled = false
            self.desktopLyricsEnabled = false
            self.currentLyrics = ""
            self.currentSongTitle = ""
            self.currentArtist = ""
            self.nowPlayingInfo.removeAll()
            self.desktopLyricsStyle.removeAll()
            
            // 清理 channel 引用
            self.channel = nil
            
            result(nil)
        }
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
                // 状态栏歌词只显示第一行，处理多行歌词的情况
                let lines = self.currentLyrics.components(separatedBy: .newlines)
                let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // 限制歌词长度，避免状态栏过长
                let maxLength = 50
                let displayLyrics = firstLine.count > maxLength 
                    ? String(firstLine.prefix(maxLength)) + "..."
                    : firstLine
                
                if displayLyrics.isEmpty {
                    statusItem.button?.title = "♪ ..."
                } else {
                    statusItem.button?.title = "♪ \(displayLyrics)"
                }
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = self.desktopLyricsWindow {
                // 清理手势识别器
                if let contentView = window.contentView {
                    contentView.gestureRecognizers.forEach { recognizer in
                        contentView.removeGestureRecognizer(recognizer)
                    }
                }
                
                // 清理按钮目标引用
                self.clearButtonTargets(in: window.contentView)
                
                // 使用 orderOut 而不是 close 来避免内存问题
                window.orderOut(nil)
                
                // 清理引用
                self.desktopLyricsWindow = nil
                self.desktopLyricsLabel = nil
                self.playPauseButton = nil
            }
            
            result(nil)
        }
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
        
        // 获取样式配置
        let fontSize = desktopLyricsStyle["fontSize"] as? Double ?? 24.0
        let fontColor = desktopLyricsStyle["fontColor"] as? String ?? "#FFFFFF"
        let backgroundColor = desktopLyricsStyle["backgroundColor"] as? String ?? "#80000000"
        let _ = desktopLyricsStyle["initialPosition"] as? String ?? "center-top"
        
        // 动态计算窗口宽度
        let windowWidth = calculateOptimalWindowWidth(for: currentLyrics, fontSize: fontSize)
        let windowHeight: Double = 80
        
        // 获取可见屏幕区域（排除菜单栏和Dock）
        let visibleFrame = screen.visibleFrame
        
        // 计算初始位置 - 屏幕中心偏上
        var x = (visibleFrame.width - windowWidth) / 2 + visibleFrame.minX
        var y = visibleFrame.maxY - windowHeight - 100 // 距离顶部100像素
        
        // 确保窗口在可见区域内
        if x < visibleFrame.minX {
            x = visibleFrame.minX + 10
        }
        if x + windowWidth > visibleFrame.maxX {
            x = visibleFrame.maxX - windowWidth - 10
        }
        if y < visibleFrame.minY {
            y = visibleFrame.minY + 10
        }
        if y + windowHeight > visibleFrame.maxY {
            y = visibleFrame.maxY - windowHeight - 10
        }
        
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
        
        // 创建歌词标签 - 使用动态宽度，支持多行显示
        let labelWidth = windowWidth - 20 // 左右各留10像素边距
        let label = NSTextField(frame: NSRect(x: 10, y: 40, width: labelWidth, height: 30))
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = NSColor.clear
        label.textColor = hexToNSColor(fontColor)
        label.font = NSFont.systemFont(ofSize: fontSize)
        label.alignment = .center
        label.stringValue = currentLyrics.isEmpty ? "♪ 暂无歌词" : currentLyrics
        
        // 启用多行显示
        label.maximumNumberOfLines = 0 // 0表示不限制行数
        label.lineBreakMode = .byWordWrapping
        label.usesSingleLineMode = false
        
        // 创建播放控制按钮容器 - 居中布局，只包含播放控件
        let controlsView = NSView(frame: NSRect(x: 0, y: 5, width: windowWidth, height: 30))
        
        // 计算播放控件位置 - 居中布局（只有3个播放控件）
        let buttonWidth: Double = 30
        let buttonSpacing: Double = 10
        let playbackButtonsWidth = buttonWidth * 3 + buttonSpacing * 2 // 3个播放按钮，2个间距
        let playbackStartX = (windowWidth - playbackButtonsWidth) / 2
        
        // 上一曲按钮
        let prevButton = NSButton(frame: NSRect(x: playbackStartX, y: 0, width: buttonWidth, height: 30))
        prevButton.title = "⏮"
        prevButton.bezelStyle = .circular
        prevButton.target = self
        prevButton.action = #selector(previousTrack)
        
        // 播放/暂停按钮
        let playPauseButton = NSButton(frame: NSRect(x: playbackStartX + buttonWidth + buttonSpacing, y: 0, width: buttonWidth, height: 30))
        playPauseButton.title = isPlaying ? "⏸" : "▶"
        playPauseButton.bezelStyle = .circular
        playPauseButton.target = self
        playPauseButton.action = #selector(togglePlayPause)
        
        // 保存按钮引用
        self.playPauseButton = playPauseButton
        
        // 下一曲按钮
        let nextButton = NSButton(frame: NSRect(x: playbackStartX + (buttonWidth + buttonSpacing) * 2, y: 0, width: buttonWidth, height: 30))
        nextButton.title = "⏭"
        nextButton.bezelStyle = .circular
        nextButton.target = self
        nextButton.action = #selector(nextTrack)
        
        // 关闭按钮 - 固定在右下角
        let closeButtonSize: Double = 20
        let closeButton = NSButton(frame: NSRect(x: windowWidth - closeButtonSize - 5, y: 5, width: closeButtonSize, height: closeButtonSize))
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
        guard desktopLyricsEnabled, let label = desktopLyricsLabel, let window = desktopLyricsWindow else { return }
        
        DispatchQueue.main.async {
            let displayText = self.currentLyrics.isEmpty ? "♪ 暂无歌词" : self.currentLyrics
            label.stringValue = displayText
            
            // 获取当前字体大小
            let fontSize = self.desktopLyricsStyle["fontSize"] as? Double ?? 16.0
            
            // 计算歌词行数
            let lineCount = max(1, displayText.components(separatedBy: "\n").count)
            
            // 计算新的窗口尺寸
            let newWidth = self.calculateOptimalWindowWidth(for: displayText, fontSize: fontSize)
            let lineHeight: CGFloat = fontSize * 1.4 // 行高为字体大小的1.4倍
            let lyricHeight = lineHeight * CGFloat(lineCount)
            let newHeight = lyricHeight + 40 // 歌词高度 + 控制按钮区域(30) + 边距(10)
            
            let currentFrame = window.frame
            let sizeChanged = abs(currentFrame.width - newWidth) > 0.5 || abs(currentFrame.height - newHeight) > 0.5
            
            // 如果窗口尺寸发生变化，调整窗口大小和位置
            if sizeChanged {
                // 以当前窗口中心为锚点，自适应向上下左右动态扩展
                let centerX = currentFrame.midX
                let centerY = currentFrame.midY
                
                // 获取屏幕边界
                let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
                
                // 计算新窗口位置，确保窗口不会超出屏幕边界
                var newX = centerX - newWidth / 2
                var newY = centerY - newHeight / 2
                
                // 检查左边界
                if newX < screenFrame.minX {
                    newX = screenFrame.minX + 10 // 留10像素边距
                }
                // 检查右边界
                if newX + newWidth > screenFrame.maxX {
                    newX = screenFrame.maxX - newWidth - 10 // 留10像素边距
                }
                // 检查下边界
                if newY < screenFrame.minY {
                    newY = screenFrame.minY + 10 // 留10像素边距
                }
                // 检查上边界
                if newY + newHeight > screenFrame.maxY {
                    newY = screenFrame.maxY - newHeight - 10 // 留10像素边距
                }
                
                let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
                window.setFrame(newFrame, display: true, animate: true)
                
                // 更新歌词标签的位置和大小
                let labelY: CGFloat = 30 // 控制按钮高度(20) + 间距(10)
                label.frame = NSRect(x: 10, y: labelY, width: newWidth - 20, height: lyricHeight)
            }
            
            // 始终更新按钮位置，确保关闭按钮在正确位置
            self.updateButtonPositions(windowWidth: sizeChanged ? newWidth : currentFrame.width)
            
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
    
    /// 更新按钮位置，确保关闭按钮始终在右下角
    private func updateButtonPositions(windowWidth: CGFloat) {
        guard let label = desktopLyricsLabel, let backgroundView = label.superview else { return }
        
        let buttonY: CGFloat = 5
        let buttonSpacing: CGFloat = 10
        let buttonWidth: CGFloat = 30
        let closeButtonSize: CGFloat = 20
        
        // 计算播放控件的居中位置（3个播放按钮）
        let playbackButtonsWidth: CGFloat = buttonWidth * 3 + buttonSpacing * 2
        let playbackStartX = (windowWidth - playbackButtonsWidth) / 2
        
        // 重新定位所有按钮
        var playbackButtonIndex = 0
        for subview in backgroundView.subviews {
            if let button = subview as? NSButton, button != label {
                // 检查是否为关闭按钮（通过标题判断）
                if button.title == "✕" {
                    // 关闭按钮固定在右下角
                    button.frame = NSRect(x: windowWidth - closeButtonSize - 5, y: buttonY, width: closeButtonSize, height: closeButtonSize)
                } else {
                    // 播放控件居中布局
                    if playbackButtonIndex < 3 {
                        let buttonX = playbackStartX + CGFloat(playbackButtonIndex) * (buttonWidth + buttonSpacing)
                        button.frame = NSRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonWidth)
                        playbackButtonIndex += 1
                    }
                }
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
                // 清理手势识别器
                if let contentView = window.contentView {
                    contentView.gestureRecognizers.forEach { recognizer in
                        contentView.removeGestureRecognizer(recognizer)
                    }
                }
                
                // 清理按钮目标引用
                self.clearButtonTargets(in: window.contentView)
                
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
    
    // 清理按钮目标引用的辅助方法
    private func clearButtonTargets(in view: NSView?) {
        guard let view = view else { return }
        
        // 递归清理所有子视图中的按钮
        for subview in view.subviews {
            if let button = subview as? NSButton {
                button.target = nil
                button.action = nil
            }
            // 递归处理子视图
            clearButtonTargets(in: subview)
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
    
    // 计算基于歌词长度的最佳窗口宽度
    private func calculateOptimalWindowWidth(for lyrics: String, fontSize: Double) -> Double {
        let displayText = lyrics.isEmpty ? "♪ 暂无歌词" : lyrics
        
        // 创建临时字体来测量文本宽度
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes = [NSAttributedString.Key.font: font]
        let textSize = displayText.size(withAttributes: attributes)
        
        // 计算所需的文本宽度
        let textWidth = textSize.width
        
        // 添加边距和控制按钮所需的空间
        let horizontalPadding: Double = 40 // 左右各20像素边距
        let controlButtonsWidth: Double = 150 // 控制按钮区域宽度（4个按钮+间距）
        
        // 计算最终窗口宽度
        let minWidth: Double = 300 // 最小宽度，确保控制按钮有足够空间
        let maxWidth: Double = 800 // 最大宽度，避免窗口过宽
        
        // 取文本宽度和控制按钮宽度的较大值，再加上边距
        let requiredWidth = max(textWidth + horizontalPadding, controlButtonsWidth + horizontalPadding)
        
        // 确保宽度在合理范围内
        return max(minWidth, min(maxWidth, requiredWidth))
    }
}