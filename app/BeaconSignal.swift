import Foundation

/// Wire format observed while the official iPhone app successfully powered on
/// the user's Z7X. The 21-byte iBeacon body contains a 16-byte proximity UUID,
/// two-byte major, two-byte minor and one-byte measured power.
enum BeaconSignal {
    static func valid(_ body: Data) -> Bool {
        let b = [UInt8](body)
        return b.count == 21 && b[6...8].elementsEqual([0xff, 0xff, 0xff])
            && b[9...14].elementsEqual([0x33, 0x43, 0x52, 0x4b, 0x54, 0x4d])
            && b[15...20].allSatisfy { $0 == 0 }
    }

    static func fromManufacturerData(_ data: Data) -> Data? {
        guard data.count == 25, data.prefix(4) == Data([0x4c, 0, 2, 0x15]) else { return nil }
        let body = Data(data.dropFirst(4))
        return valid(body) ? body : nil
    }

    /// Android app's BleConfig.buildOpenData: company ID, sequence byte,
    /// reversed target address, broadcast marker, and explicit wake command.
    static func androidWakeData(_ body: Data) -> Data? {
        guard valid(body) else { return nil }
        return Data([0x46, 0, 0]) + body.prefix(9) + Data([0x32, 0x43, 0x52, 0x4b, 0x54, 0x4d])
    }
}
