import Foundation

public struct JoyconDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let vendorID: Int
    public let productID: Int
    public let transport: String

    public init(id: String, name: String, vendorID: Int, productID: Int, transport: String) {
        self.id = id
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
        self.transport = transport
    }

    public var isJoyConLeft: Bool {
        vendorID == 0x057E && productID == 0x2006
    }

    public var displayProductID: String {
        String(format: "0x%04X", productID)
    }
}
