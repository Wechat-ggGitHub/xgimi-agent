import AppKit
import CoreBluetooth

/// Windowless agent. Initialize the BLE session while temporarily registered as
/// a regular app, then immediately restore accessory mode before any callbacks.
/// Actual daemon scheduling of this sequence was verified on this Mac.
final class WakeHelper: NSObject, NSApplicationDelegate, CBPeripheralManagerDelegate {
    let attempt: UUID
    var peripheral: CBPeripheralManager?
    var activity: NSObjectProtocol?
    var started = false
    var finished = false
    var accepted = false
    var broadcastStop: DispatchWorkItem?

    init(attempt: UUID) { self.attempt = attempt }

    func report(_ message: String, completed: Bool = false) {
        WakeResult(attempt: attempt, message: message, completed: completed, accepted: accepted).save()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "发送投影仪开机广播")
        report("等待 Mac 蓝牙就绪…")
        // CoreBluetooth records the application type during manager creation.
        // Both transitions happen in this one run-loop turn: the helper starts
        // as an agent, never activates or creates windows, and returns to agent
        // mode before dispatching the asynchronous Bluetooth callbacks.
        NSApp.setActivationPolicy(.regular)
        peripheral = CBPeripheralManager(delegate: self, queue: .main, options: [CBPeripheralManagerOptionShowPowerAlertKey: false])
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            guard let self, !self.finished else { return }
            self.finish("蓝牙准备超时；请确认已允许蓝牙权限。")
        }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard !finished else { return }
        switch peripheral.state {
        case .poweredOn:
            guard !started else { return }
            guard let body = UserDefaults(suiteName: "io.github.wechatgg.xgimi-agent")?.data(forKey: "wakeBeaconData"), BeaconSignal.valid(body) else {
                finish("没有有效的开机信号，请在主应用重新学习。"); return
            }
            started = true
            report("正在发送蓝牙开机信号…")
            peripheral.startAdvertising(["kCBAdvDataAppleBeaconKey": body])
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                guard let self, !self.finished, !self.accepted else { return }
                self.finish("未收到系统广播回执，已停止。")
            }
        case .poweredOff: finish("Mac 蓝牙已关闭。")
        case .unauthorized: finish("请在系统设置中允许「极米开机助手」使用蓝牙。")
        case .unsupported: finish("系统不支持此蓝牙发送方式。")
        default: break
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard !finished else { return }
        if let error { finish("系统拒绝广播：\(error.localizedDescription)"); return }
        accepted = true
        report("正在发送开机信号，请稍等…")
        let stop = DispatchWorkItem { [weak self] in self?.finish("开机广播已结束，请等待投影画面亮起。") }
        broadcastStop = stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: stop)
    }

    func finish(_ message: String) {
        guard !finished else { return }; finished = true
        broadcastStop?.cancel(); if peripheral?.isAdvertising == true { peripheral?.stopAdvertising() }
        report(message, completed: true)
        NSApp.terminate(nil)
    }
    func applicationWillTerminate(_ notification: Notification) {
        broadcastStop?.cancel(); if peripheral?.isAdvertising == true { peripheral?.stopAdvertising() }
        if !finished { report("发送助手已退出。", completed: true) }
        if let activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil }
    }
}

@main struct WakeHelperLauncher {
    static func main() {
        guard let index = CommandLine.arguments.firstIndex(of: "--attempt"), CommandLine.arguments.count > index + 1,
              let attempt = UUID(uuidString: CommandLine.arguments[index + 1]) else { return }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = WakeHelper(attempt: attempt)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
