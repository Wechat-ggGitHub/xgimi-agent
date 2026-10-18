import AppKit
import CoreBluetooth

final class BluetoothWake: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var scanning = false
    @Published var busy = false
    @Published var message = "已保存的信号可直接测试；尚未学习时，请先从 iPhone 极米 App 采样。"
    @Published var signal: Data? = {
        guard let body = UserDefaults.standard.data(forKey: "wakeBeaconData"), BeaconSignal.valid(body) else { return nil }
        return body
    }()
    @Published var verified = UserDefaults.standard.bool(forKey: "beaconWakeVerified")
    @Published var rawInterface = "正在检查蓝牙"
    @Published var interfaceAvailable = false
    var onWake: ((String) -> Void)?
    private var central: CBCentralManager?
    private var scanRequested = false
    private var learnDeadline: DispatchWorkItem?
    private var helper: NSRunningApplication?
    private var watcher: Timer?
    private var attempt: UUID?

    func probe() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        } else if let central { centralManagerDidUpdateState(central) }
    }

    func learn() {
        guard !busy else { return }
        scanRequested = true
        message = "准备采样 iPhone 的开机广播…"
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        } else { centralManagerDidUpdateState(central!) }
    }

    func stopLearning() {
        central?.stopScan(); learnDeadline?.cancel(); scanning = false; scanRequested = false
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        interfaceAvailable = central.state == .poweredOn
        switch central.state {
        case .poweredOn: rawInterface = "Mac 蓝牙已就绪 · 内置开机助手"
        case .poweredOff: rawInterface = "Mac 蓝牙已关闭"
        case .unauthorized: rawInterface = "请在系统设置中允许「极米遥控」使用蓝牙"
        case .unsupported: rawInterface = "系统不支持蓝牙"
        default: rawInterface = "正在等待蓝牙就绪"
        }
        if central.state == .poweredOn && scanRequested {
            guard !scanning else { return }
            scanning = true
            message = "正在采样：让 iPhone 靠近 Mac，在极米 App 点一次开机。"
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            let task = DispatchWorkItem { [weak self] in
                self?.stopLearning(); self?.message = "这次没有收到匹配信号。可重新开始学习，再点手机 App 的开机。"
            }
            learnDeadline = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: task)
        } else if central.state == .poweredOff || central.state == .unauthorized || central.state == .unsupported {
            stopLearning(); message = "请确认 Mac 蓝牙已开启，并允许此 App 使用蓝牙。"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {
        guard scanning, let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              let body = BeaconSignal.fromManufacturerData(manufacturer) else { return }
        signal = body; verified = false
        UserDefaults.standard.set(body, forKey: "wakeBeaconData")
        UserDefaults.standard.set(false, forKey: "beaconWakeVerified")
        stopLearning()
        message = "已保存 iPhone 官方开机信号。请将投影仪关机后测试 Mac 开机。"
    }

    func wake() {
        guard !busy else { return }
        guard let body = signal, BeaconSignal.valid(body) else { message = "请先从 iPhone 极米 App 学习开机信号。"; onWake?(message); return }
        guard interfaceAvailable else { message = rawInterface; onWake?(message); return }
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/极米开机助手.app")
        guard FileManager.default.fileExists(atPath: helperURL.path) else {
            message = "内置开机助手缺失，请重新安装应用。"; onWake?(message); return
        }
        stopLearning(); busy = true
        let token = UUID(); attempt = token
        message = "正在准备蓝牙开机…"; onWake?(message)
        UserDefaults.standard.synchronize()
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--attempt", token.uuidString]
        config.activates = false; config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: helperURL, configuration: config) { [weak self] application, error in
            DispatchQueue.main.async {
                guard let self, self.attempt == token else { application?.terminate(); return }
                if let error { self.finish("无法启动开机助手：\(error.localizedDescription)"); return }
                self.helper = application
            }
        }
        let started = Date()
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self, self.attempt == token else { return }
            if let data = try? Data(contentsOf: WakeResult.url(for: token)),
               let result = try? JSONDecoder().decode(WakeResult.self, from: data), result.attempt == token {
                self.message = result.message; self.onWake?(result.message)
                if result.completed { self.finish(result.message); return }
            }
            if Date().timeIntervalSince(started) > 30 {
                self.helper?.terminate(); self.finish("发送助手超时，已停止。本次未确认开机。"); return
            }
        }
        watcher = timer; RunLoop.main.add(timer, forMode: .common)
    }

    private func finish(_ status: String) {
        watcher?.invalidate(); watcher = nil; attempt = nil; helper = nil
        busy = false; message = status; onWake?(status)
    }

    func confirmWake() {
        guard signal != nil else { return }
        verified = true; UserDefaults.standard.set(true, forKey: "beaconWakeVerified")
        message = "已记录：你确认这版菜单栏应用可以开机。"
    }

    func cancelWake() {
        guard busy else { return }
        helper?.terminate(); finish("已取消蓝牙开机。")
    }

    func stopAll() {
        stopLearning()
        helper?.terminate()
        if busy { finish("已停止蓝牙开机。") }
    }
}
