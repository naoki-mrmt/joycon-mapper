import CoreFoundation
import Foundation
import IOKit.hid
import JoyconMapping

public final class JoyconHIDClient {
    public var onDevicesChanged: (([JoyconDevice]) -> Void)?
    public var onInput: ((ControllerInput) -> Void)?

    private var manager: IOHIDManager?
    private var devicesByID: [String: JoyconDevice] = [:]
    private var reportRegistrationsByDeviceID: [String: InputReportRegistration] = [:]
    private var buttonStatesByInputID: [String: Bool] = [:]
    private var analogValuesByInputID: [String: Double] = [:]

    public init() {}

    deinit {
        stop()
    }

    public func start() throws {
        guard manager == nil else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(0))
        self.manager = manager

        let matchers = [
            matcher(productID: 0x2006), // Joy-Con (L)
            matcher(productID: 0x2007), // Joy-Con (R), useful while debugging.
            matcher(productID: 0x2009)  // Switch Pro Controller.
        ] as CFArray

        IOHIDManagerSetDeviceMatchingMultiple(manager, matchers)

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovedCallback, context)
        IOHIDManagerRegisterInputValueCallback(manager, inputValueCallback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            self.manager = nil
            throw JoyconHIDError.openFailed(result)
        }

        refreshDevices()
    }

    public func stop() {
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        devicesByID = [:]
        reportRegistrationsByDeviceID = [:]
        buttonStatesByInputID = [:]
        analogValuesByInputID = [:]
        onDevicesChanged?([])
    }

    public func refreshDevices() {
        guard let manager else {
            onDevicesChanged?([])
            return
        }

        let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        deviceSet.forEach(registerInputReportCallbackIfNeeded)
        let devices = deviceSet.map(Self.snapshot).sorted { $0.name < $1.name }
        devicesByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        onDevicesChanged?(devices)
    }

    fileprivate func handleMatched(device: IOHIDDevice) {
        registerInputReportCallbackIfNeeded(device)
        let snapshot = Self.snapshot(device)
        devicesByID[snapshot.id] = snapshot
        onDevicesChanged?(devicesByID.values.sorted { $0.name < $1.name })
    }

    fileprivate func handleRemoved(device: IOHIDDevice) {
        let snapshot = Self.snapshot(device)
        devicesByID.removeValue(forKey: snapshot.id)
        reportRegistrationsByDeviceID.removeValue(forKey: snapshot.id)
        let prefix = "\(snapshot.id)|"
        buttonStatesByInputID = buttonStatesByInputID.filter { !$0.key.hasPrefix(prefix) }
        analogValuesByInputID = analogValuesByInputID.filter { !$0.key.hasPrefix(prefix) }
        onDevicesChanged?(devicesByID.values.sorted { $0.name < $1.name })
    }

    fileprivate func handle(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = Int(IOHIDElementGetUsagePage(element))
        let usage = Int(IOHIDElementGetUsage(element))
        let control = ControllerControl.fromHID(usagePage: usagePage, usage: usage)
        let integerValue = IOHIDValueGetIntegerValue(value)
        let logicalMin = IOHIDElementGetLogicalMin(element)
        let logicalMax = IOHIDElementGetLogicalMax(element)
        let normalized = normalize(value: integerValue, min: logicalMin, max: logicalMax)

        let device = Self.snapshot(IOHIDElementGetDevice(element))
        let fallbackID = "unknown-\(usagePage)-\(usage)"
        let input = ControllerInput(
            deviceID: device.id.isEmpty ? fallbackID : device.id,
            deviceName: device.name,
            control: control,
            value: integerValue,
            normalizedValue: normalized
        )

        onInput?(input)
    }

    fileprivate func handleReport(device: IOHIDDevice, reportID: UInt32, bytes: [UInt8]) {
        let snapshot = Self.snapshot(device)
        for input in JoyConReportParser.inputs(from: bytes, reportID: reportID, device: snapshot) {
            let stateKey = "\(snapshot.id)|\(input.triggerID)"
            switch input.control.kind {
            case .axis:
                let previous = analogValuesByInputID[stateKey]
                guard previous == nil || abs((previous ?? 0) - input.normalizedValue) > 0.015 else {
                    continue
                }
                analogValuesByInputID[stateKey] = input.normalizedValue
                onInput?(input)
            default:
                let previous = buttonStatesByInputID[stateKey] ?? false
                guard previous != input.isPressed else { continue }
                buttonStatesByInputID[stateKey] = input.isPressed
                onInput?(input)
            }
        }
    }

    private func registerInputReportCallbackIfNeeded(_ device: IOHIDDevice) {
        let snapshot = Self.snapshot(device)
        guard reportRegistrationsByDeviceID[snapshot.id] == nil else { return }

        let registration = InputReportRegistration()
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceRegisterInputReportCallback(
            device,
            registration.buffer,
            registration.capacity,
            inputReportCallback,
            context
        )
        reportRegistrationsByDeviceID[snapshot.id] = registration
    }

    private func matcher(productID: Int) -> CFDictionary {
        [
            kIOHIDVendorIDKey as String: 0x057E,
            kIOHIDProductIDKey as String: productID
        ] as CFDictionary
    }

    private static func snapshot(_ device: IOHIDDevice) -> JoyconDevice {
        let vendorID = intProperty(device, key: kIOHIDVendorIDKey)
        let productID = intProperty(device, key: kIOHIDProductIDKey)
        let product = stringProperty(device, key: kIOHIDProductKey) ?? "Nintendo Controller"
        let transport = stringProperty(device, key: kIOHIDTransportKey) ?? "Unknown"
        let location = intProperty(device, key: kIOHIDLocationIDKey)
        let id = "\(vendorID)-\(productID)-\(location)-\(product)"

        return JoyconDevice(
            id: id,
            name: product,
            vendorID: vendorID,
            productID: productID,
            transport: transport
        )
    }

    private static func intProperty(_ device: IOHIDDevice, key: String) -> Int {
        IOHIDDeviceGetProperty(device, key as CFString) as? Int ?? 0
    }

    private static func stringProperty(_ device: IOHIDDevice, key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }
}

public enum JoyconHIDError: Error, LocalizedError {
    case openFailed(IOReturn)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let result):
            "Could not open HID manager: \(result)"
        }
    }
}

private func normalize(value: Int, min: Int, max: Int) -> Double {
    guard max > min else { return value == 0 ? 0 : 1 }
    let range = Double(max - min)
    return (Double(value - min) / range * 2) - 1
}

private let deviceMatchedCallback: IOHIDDeviceCallback = { context, _, _, device in
    guard let context else { return }
    let client = Unmanaged<JoyconHIDClient>.fromOpaque(context).takeUnretainedValue()
    client.handleMatched(device: device)
}

private let deviceRemovedCallback: IOHIDDeviceCallback = { context, _, _, device in
    guard let context else { return }
    let client = Unmanaged<JoyconHIDClient>.fromOpaque(context).takeUnretainedValue()
    client.handleRemoved(device: device)
}

private let inputValueCallback: IOHIDValueCallback = { context, _, _, value in
    guard let context else { return }
    let client = Unmanaged<JoyconHIDClient>.fromOpaque(context).takeUnretainedValue()
    client.handle(value: value)
}

private let inputReportCallback: IOHIDReportCallback = { context, _, sender, _, reportID, report, reportLength in
    guard let context, let sender else { return }
    let client = Unmanaged<JoyconHIDClient>.fromOpaque(context).takeUnretainedValue()
    let device = unsafeBitCast(sender, to: IOHIDDevice.self)
    let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
    client.handleReport(device: device, reportID: reportID, bytes: bytes)
}

private final class InputReportRegistration {
    let capacity = 64
    let buffer: UnsafeMutablePointer<UInt8>

    init() {
        buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        buffer.initialize(repeating: 0, count: capacity)
    }

    deinit {
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
    }
}
