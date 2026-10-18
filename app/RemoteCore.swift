import Foundation
import Network
import CoreBluetooth
import AppKit
import ServiceManagement

enum RemoteCommand: String, CaseIterable {
    case up, down, left, right, ok, back, home, menu, volumeDown, volumeUp, mute, powerOff
    var code: Int {
        switch self {
        case .up: return 36; case .down: return 38; case .left: return 50; case .right: return 37
        case .ok: return 49; case .back: return 48; case .home: return 35; case .menu: return 139
        case .volumeDown: return 114; case .volumeUp: return 115; case .mute: return 113; case .powerOff: return 30
        }
    }
    var label: String {
        switch self {
        case .up: return "向上"; case .down: return "向下"; case .left: return "向左"; case .right: return "向右"
        case .ok: return "确认"; case .back: return "返回"; case .home: return "主页"; case .menu: return "菜单"
        case .volumeDown: return "音量 −"; case .volumeUp: return "音量 +"; case .mute: return "静音切换"; case .powerOff: return "关机"
        }
    }
    var packet: Data { Data("KEYPRESSES:\(code)".utf8) }
}

final class RemoteModel: ObservableObject {
    @Published var host = UserDefaults.standard.string(forKey: "projectorIP") ?? ""
    @Published var reachable: Bool? = nil
    @Published var status = "准备就绪"
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    let bluetooth = BluetoothWake()
    private var timer: Timer?
    private var checkConnection: NWConnection?
    private var pending: [UUID: NWConnection] = [:]
    private var checkID = UUID()
    private var checking = false

    init() {
        bluetooth.onWake = { [weak self] value in self?.status = value }
        bluetooth.probe()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.check() }
    }

    static func validIP(_ host: String) -> Bool { IPv4Address(host) != nil }

    func saveHost(_ value: String) -> Bool {
        let ip = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.validIP(ip) else { status = "请输入有效的 IP 地址"; return false }
        host = ip; UserDefaults.standard.set(ip, forKey: "projectorIP"); reachable = nil; checking = false
        checkConnection?.cancel(); checkID = UUID(); check(); status = "已保存投影仪地址"
        return true
    }

    func check() {
        guard !checking, Self.validIP(host) else { return }
        checking = true
        let token = UUID(); checkID = token
        let connection = NWConnection(host: NWEndpoint.Host(host), port: 8080, using: .tcp)
        checkConnection = connection
        func finish(_ available: Bool) {
            guard self.checkID == token, self.checking else { return }
            self.checking = false; self.reachable = available
            connection.stateUpdateHandler = nil; connection.cancel(); self.checkConnection = nil
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready: finish(true)
            case .failed: finish(false)
            default: break
            }
        }
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { finish(false) }
    }

    func send(_ command: RemoteCommand) {
        guard Self.validIP(host) else { status = "请先设置正确的投影仪地址"; return }
        let id = UUID()
        let connection = NWConnection(host: NWEndpoint.Host(host), port: 16735, using: .udp)
        pending[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                connection.stateUpdateHandler = nil
                connection.send(content: command.packet, completion: .contentProcessed { error in
                    DispatchQueue.main.async {
                        if self.pending[id] != nil {
                            self.status = error == nil ? "已发送：\(command.label)" : "发送失败，请检查网络"
                            self.pending.removeValue(forKey: id)?.cancel()
                        }
                    }
                })
            case .failed:
                self.status = "发送失败，请检查网络"; self.pending.removeValue(forKey: id)?.cancel()
            default: break
            }
        }
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if let remaining = self?.pending.removeValue(forKey: id) {
                remaining.cancel(); self?.status = "发送超时，请检查网络"
            }
        }
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            status = SMAppService.mainApp.status == .requiresApproval ? "请在系统设置中允许登录项" : (loginEnabled ? "已开启登录时启动" : "已关闭登录时启动")
        } catch { status = "登录项设置未完成：\(error.localizedDescription)" }
    }
}
