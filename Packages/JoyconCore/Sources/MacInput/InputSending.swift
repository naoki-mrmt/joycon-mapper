import JoyconMapping

public protocol InputSending: AnyObject {
    var isAccessibilityTrusted: Bool { get }
    func requestAccessibilityTrust()
    func post(shortcut: KeyboardShortcut)
    func setShortcut(_ shortcut: KeyboardShortcut, isPressed: Bool)
    func setModifiers(_ modifiers: KeyboardShortcut.Modifiers, isPressed: Bool)
    func moveMouse(deltaX: Double, deltaY: Double)
    func clickMouse(_ button: MouseClickButton)
    func setMouseButton(_ button: MouseClickButton, isPressed: Bool)
    func scroll(deltaX: Double, deltaY: Double)
}

extension MacInputSender: InputSending {}
