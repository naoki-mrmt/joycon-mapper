enum Tuning {
    static let mouseSpeedRange: ClosedRange<Double> = 800...7200
    static let mouseSpeedStep = 100.0
    static let mouseDeadzoneRange: ClosedRange<Double> = 0.05...0.45
    static let mouseAccelerationRange: ClosedRange<Double> = 1.0...2.4
    static let inputLogLimit = 80
    static let mouseTicksPerSecond = 120.0
    static let deviceRefreshInterval = 3.0
}
