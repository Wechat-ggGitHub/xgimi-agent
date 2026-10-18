import AppKit
import SwiftUI
import Combine

struct RemoteButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(primary ? Color.white : Color.primary)
            .background(primary ? Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1) : Color.primary.opacity(configuration.isPressed ? 0.13 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct RemoteView: View {
    @ObservedObject var model: RemoteModel
    @ObservedObject var bluetooth: BluetoothWake
    var openSettings: () -> Void
    var openBluetooth: () -> Void

    func key(_ title: String, _ symbol: String, _ command: RemoteCommand, _ shortcut: KeyEquivalent? = nil, primary: Bool = false) -> some View {
        let button = Button { model.send(command) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: primary ? 21 : 18, weight: .medium))
                if !title.isEmpty { Text(title).font(.system(size: 10, weight: .medium)) }
            }.frame(width: 64, height: 60)
        }
        .buttonStyle(RemoteButtonStyle(primary: primary))
        .accessibilityLabel(command.label)
        .help(command.label)
        return Group {
            if let shortcut = shortcut { button.keyboardShortcut(shortcut, modifiers: []) } else { button }
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "videoprojector.fill")
                    .font(.system(size: 22)).foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44).background(Color.accentColor.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("极米 Z7X").font(.system(size: 18, weight: .semibold))
                    HStack(spacing: 5) {
                        Circle().fill(model.reachable == true ? Color.green : (model.reachable == nil ? Color.secondary : Color.orange)).frame(width: 5, height: 5)
                        Text(model.reachable == true ? "设备可达 · Wi-Fi 遥控" : (model.reachable == nil ? "正在检查网络" : "设备未响应 · 请检查电源和网络"))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: openSettings) { Image(systemName: "gearshape").font(.system(size: 15)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("设置")
            }

            VStack(spacing: 7) {
                key("", "chevron.up", .up, .upArrow)
                HStack(spacing: 7) {
                    key("", "chevron.left", .left, .leftArrow)
                    key("确认", "checkmark", .ok, .return, primary: true)
                    key("", "chevron.right", .right, .rightArrow)
                }
                key("", "chevron.down", .down, .downArrow)
            }

            HStack(spacing: 9) {
                key("返回", "arrow.uturn.backward", .back, "b")
                key("主页", "house", .home, "h")
                key("菜单", "line.3.horizontal", .menu, "m")
            }
            HStack(spacing: 0) {
                Button { model.send(.volumeDown) } label: { Image(systemName: "speaker.minus").frame(maxWidth: .infinity).frame(height: 38) }.help("降低音量")
                Divider().frame(height: 15)
                Button { model.send(.mute) } label: { Image(systemName: "speaker.slash").frame(maxWidth: .infinity).frame(height: 38) }.help("静音切换")
                Divider().frame(height: 15)
                Button { model.send(.volumeUp) } label: { Image(systemName: "speaker.plus").frame(maxWidth: .infinity).frame(height: 38) }.help("提高音量")
            }
            .buttonStyle(.plain).font(.system(size: 16)).background(Color.primary.opacity(0.045)).clipShape(RoundedRectangle(cornerRadius: 12))

            Divider()
            HStack(spacing: 10) {
                Button {
                    if bluetooth.signal != nil && bluetooth.interfaceAvailable { bluetooth.wake() } else { openBluetooth() }
                } label: {
                    Label(bluetooth.busy ? "正在唤醒…" : (bluetooth.interfaceAvailable ? "开机" : "开机说明"), systemImage: "power")
                        .font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 37)
                }.buttonStyle(RemoteButtonStyle(primary: bluetooth.interfaceAvailable)).disabled(bluetooth.busy)
                Button { model.send(.powerOff) } label: {
                    Label("关机", systemImage: "moon").font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).frame(height: 37)
                }.buttonStyle(RemoteButtonStyle())
            }
            VStack(spacing: 4) {
                Text(model.status).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2).frame(height: 26)
                HStack {
                    Button(bluetooth.interfaceAvailable ? (bluetooth.signal == nil ? "学习蓝牙开机" : (bluetooth.verified ? "蓝牙开机已验证" : "蓝牙开机 · 待验证")) : "蓝牙开机暂不可用", action: openBluetooth)
                    Spacer()
                    if bluetooth.busy {
                        Button("取消开机") { bluetooth.cancelWake() }
                    } else { Button("退出") { NSApp.terminate(nil) } }
                }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(22).frame(width: 310).background(.regularMaterial)
        .onAppear { model.check() }
    }
}

struct SettingsView: View {
    @ObservedObject var model: RemoteModel
    @State private var draft: String
    var openBluetooth: () -> Void
    init(model: RemoteModel, openBluetooth: @escaping () -> Void) {
        self.model = model; self.openBluetooth = openBluetooth; _draft = State(initialValue: model.host)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("极米遥控设置").font(.title2.bold())
            VStack(alignment: .leading, spacing: 8) {
                Text("投影仪 IP 地址").font(.headline)
                HStack {
                    TextField("填写投影仪的 IPv4 地址", text: $draft).textFieldStyle(.roundedBorder)
                    Button("保存") { _ = model.saveHost(draft) }
                }
                Text("电脑和投影仪需要连接同一局域网。").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("登录 Mac 时启动", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
            Divider()
            Button("配置蓝牙开机…", action: openBluetooth)
            Text(model.status).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("极米遥控 · 本机运行").font(.caption).foregroundStyle(.tertiary)
        }.padding(28).frame(width: 400, height: 310)
    }
}

struct BluetoothView: View {
    @ObservedObject var bluetooth: BluetoothWake
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 24)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("用 Mac 蓝牙开机").font(.title2.bold())
                    Text(bluetooth.verified ? "已在这台 Z7X 验证" : (bluetooth.signal == nil ? "先学习一次，再测试开机" : "已保存信号 · 等待应用实测"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("投影仪保持接通电源。点击开机后，在菜单栏内显示发送进度，约 8 秒完成。平时不需要手机或遥控器配合。")
                .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            if bluetooth.signal == nil || bluetooth.scanning {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1  让 iPhone 靠近 Mac，打开官方极米 App。")
                    Text("2  点击下方「开始学习」，再在手机 App 点一次开机。")
                    Text("3  学习完成后，将投影仪关机，再用 Mac 测试。")
                }.font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Button(bluetooth.scanning ? "停止学习" : (bluetooth.signal == nil ? "开始学习" : "重新学习")) {
                    if bluetooth.scanning { bluetooth.stopLearning() } else { bluetooth.learn() }
                }.disabled(bluetooth.busy || !bluetooth.interfaceAvailable)
                if bluetooth.scanning { ProgressView().controlSize(.small) }
                if bluetooth.signal != nil {
                    Label("已保存开机信号", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                }
            }
            Text(bluetooth.message).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).frame(minHeight: 38, alignment: .topLeading)
            HStack {
                Button(bluetooth.busy ? "正在发送…" : "测试开机") { bluetooth.wake() }
                    .buttonStyle(.borderedProminent).disabled(bluetooth.signal == nil || bluetooth.busy || bluetooth.scanning || !bluetooth.interfaceAvailable)
                if bluetooth.signal != nil && !bluetooth.verified && bluetooth.interfaceAvailable {
                    Button("确认：这版开机成功") { bluetooth.confirmWake() }.disabled(bluetooth.busy)
                }
            }
            Divider()
            HStack {
                Text(bluetooth.rawInterface).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("重新检测") { bluetooth.probe() }.font(.caption).disabled(bluetooth.busy)
            }
            Text("信号仅保存在本机；系统接受广播不代表投影仪已经亮起。")
                .font(.system(size: 10)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }.padding(26).frame(width: 430)
        .onAppear { bluetooth.probe() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = RemoteModel()
    let popover = NSPopover()
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    var bluetoothWindow: NSWindow?
    var statusSubscription: AnyCancellable?
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "videoprojector", accessibilityDescription: "极米遥控")
            button.image?.isTemplate = true
            button.toolTip = "极米 Z7X 遥控器"
            button.target = self; button.action = #selector(togglePopover)
        }
        statusSubscription = model.bluetooth.$busy.receive(on: RunLoop.main).sink { [weak self] busy in
            guard let button = self?.statusItem?.button else { return }
            button.image = NSImage(systemSymbolName: busy ? "dot.radiowaves.left.and.right" : "videoprojector", accessibilityDescription: busy ? "正在发送开机信号" : "极米遥控")
            button.image?.isTemplate = true
            button.toolTip = busy ? "正在发送开机信号…" : "极米 Z7X 遥控器"
        }
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: RemoteView(model: model, bluetooth: model.bluetooth, openSettings: { [weak self] in self?.showSettings() }, openBluetooth: { [weak self] in self?.showBluetooth() }))
        model.check()
        if !UserDefaults.standard.bool(forKey: "hasLaunched") || CommandLine.arguments.contains("--show") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.showPopover() }
        }
        if CommandLine.arguments.contains("--learn") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.showBluetooth(); self.model.bluetooth.learn() }
        }
        if CommandLine.arguments.contains("--wake") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.wakeWhenReady(until: Date().addingTimeInterval(8)) }
        }
        if CommandLine.arguments.contains("--bluetooth") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.showBluetooth() }
        }
    }
    private func wakeWhenReady(until deadline: Date) {
        if model.bluetooth.interfaceAvailable { model.bluetooth.wake(); return }
        guard Date() < deadline else { model.status = model.bluetooth.rawInterface; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.wakeWhenReady(until: deadline) }
    }
    @objc func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }
    func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: "极米遥控设置", view: SettingsView(model: model, openBluetooth: { [weak self] in self?.showBluetooth() }))
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func showBluetooth() {
        popover.performClose(nil)
        if bluetoothWindow == nil { bluetoothWindow = makeWindow(title: "蓝牙开机", view: BluetoothView(bluetooth: model.bluetooth)) }
        NSApp.activate(ignoringOtherApps: true); bluetoothWindow?.makeKeyAndOrderFront(nil)
    }
    func makeWindow<Content: View>(title: String, view: Content) -> NSWindow {
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPopover(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.bluetooth.stopAll() }
}

@main struct Launcher {
    static func main() {
        if let index = CommandLine.arguments.firstIndex(of: "--import-beacon"), CommandLine.arguments.count > index + 1 {
            guard let body = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1])), BeaconSignal.valid(body) else {
                fputs("Invalid beacon capture; nothing saved\n", stderr); exit(1)
            }
            UserDefaults.standard.set(body, forKey: "wakeBeaconData")
            UserDefaults.standard.set(false, forKey: "beaconWakeVerified")
            print("Saved validated wake signal to this Mac only")
            return
        }
        if CommandLine.arguments.contains("--self-test") {
            precondition(RemoteCommand.right.packet == Data("KEYPRESSES:37".utf8))
            precondition(RemoteCommand.powerOff.packet == Data("KEYPRESSES:30".utf8))
            precondition(RemoteModel.validIP("203.0.113.10"))
            precondition(!RemoteModel.validIP("203.0.113.999"))
            print("PASS: command encoding and IPv4 validation")
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > index + 1 {
            _ = NSApplication.shared
            NSApp.setActivationPolicy(.accessory)
            let model = RemoteModel()
            model.reachable = false
            let view = NSHostingView(rootView: RemoteView(model: model, bluetooth: model.bluetooth, openSettings: {}, openBluetooth: {}))
            let size = NSSize(width: 310, height: max(600, view.fittingSize.height))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = view
            view.frame = NSRect(origin: .zero, size: size)
            view.layoutSubtreeIfNeeded()
            if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) }
            }
            return
        }
        if CommandLine.arguments.contains("--transport-test") {
            let model = RemoteModel(); model.host = "127.0.0.1"
            model.send(.right)
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            print(model.status)
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
