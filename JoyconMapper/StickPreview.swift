import SwiftUI

struct StickPreview: View {
    let x: Double
    let y: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let knobSize = max(14, size * 0.18)
            let travel = radius - knobSize / 2 - 6
            let offset = CGSize(width: x * travel, height: -y * travel)

            ZStack {
                Circle()
                    .fill(.background.opacity(0.35))
                Circle()
                    .stroke(.separator, lineWidth: 1)
                Path { path in
                    path.move(to: CGPoint(x: radius, y: 8))
                    path.addLine(to: CGPoint(x: radius, y: size - 8))
                    path.move(to: CGPoint(x: 8, y: radius))
                    path.addLine(to: CGPoint(x: size - 8, y: radius))
                }
                .stroke(.secondary.opacity(0.35), lineWidth: 1)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: knobSize, height: knobSize)
                    .offset(offset)
                    .shadow(radius: 2)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
