import SwiftUI

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return p
    }
}

struct MascotView: View {
    var size: CGFloat = 100
    @State private var bounce = false

    private let bodyPink  = Color(red: 1.00, green: 0.56, blue: 0.67)
    private let innerPink = Color(red: 1.00, green: 0.71, blue: 0.78)
    private let eyeDark   = Color(red: 0.18, green: 0.11, blue: 0.41)

    var body: some View {
        ZStack {
            // Body
            Ellipse()
                .fill(bodyPink)
                .frame(width: size * 0.52, height: size * 0.46)
                .offset(y: size * 0.23)

            // Head
            Circle()
                .fill(bodyPink)
                .frame(width: size * 0.52)

            // Ears
            earView(side: -1)
            earView(side:  1)

            // Eye whites
            Circle().fill(Color.white)
                .frame(width: size * 0.13)
                .offset(x: -size * 0.11, y: -size * 0.04)
            Circle().fill(Color.white)
                .frame(width: size * 0.13)
                .offset(x:  size * 0.11, y: -size * 0.04)

            // Pupils
            Circle().fill(eyeDark)
                .frame(width: size * 0.075)
                .offset(x: -size * 0.10, y: -size * 0.03)
            Circle().fill(eyeDark)
                .frame(width: size * 0.075)
                .offset(x:  size * 0.10, y: -size * 0.03)

            // Eye shine
            Circle().fill(Color.white)
                .frame(width: size * 0.028)
                .offset(x: -size * 0.085, y: -size * 0.052)
            Circle().fill(Color.white)
                .frame(width: size * 0.028)
                .offset(x:  size * 0.125, y: -size * 0.052)

            // Smile
            SmileShape()
                .stroke(eyeDark, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: size * 0.21, height: size * 0.07)
                .offset(y: size * 0.07)

            // Floating notes
            Text("♪")
                .font(.system(size: size * 0.19))
                .foregroundStyle(.white.opacity(0.85))
                .offset(x: size * 0.37, y: -size * 0.33)
            Text("♫")
                .font(.system(size: size * 0.13))
                .foregroundStyle(.white.opacity(0.65))
                .offset(x: -size * 0.38, y: -size * 0.22)
        }
        .frame(width: size, height: size)
        .offset(y: bounce ? -5 : 0)
        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bounce)
        .onAppear { bounce = true }
    }

    private func earView(side: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(bodyPink)
                .frame(width: size * 0.18, height: size * 0.26)
            Ellipse()
                .fill(innerPink)
                .frame(width: size * 0.10, height: size * 0.16)
        }
        .offset(x: side * size * 0.22, y: -size * 0.18)
    }
}

#Preview {
    ZStack {
        Color.appPurple.ignoresSafeArea()
        MascotView(size: 120)
    }
}
