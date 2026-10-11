import Foundation

struct SyntheticStar {
    var x: Double
    var y: Double
    var amplitude: Double
    var sigmaX: Double
    var sigmaY: Double
}

/// Campi stellari sintetici: fondo + rumore gaussiano + stelle gaussiane.
enum SyntheticField {
    static func make(width: Int, height: Int, background: (Int, Int) -> Double = { _, _ in 1000 },
                     noise: Double = 10, stars: [SyntheticStar], seed: UInt64 = 1, clip: Double? = nil) -> [Float] {
        var rng = TestRandom(seed: seed)
        var v = [Double](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width { v[y * width + x] = background(x, y) + rng.gaussian(sigma: noise) }
        }
        for s in stars {
            let rx = Int(6 * s.sigmaX) + 1, ry = Int(6 * s.sigmaY) + 1
            for y in max(0, Int(s.y) - ry)...min(height - 1, Int(s.y) + ry) {
                for x in max(0, Int(s.x) - rx)...min(width - 1, Int(s.x) + rx) {
                    let dx = Double(x) - s.x, dy = Double(y) - s.y
                    v[y * width + x] += s.amplitude * exp(-(dx * dx / (2 * s.sigmaX * s.sigmaX) + dy * dy / (2 * s.sigmaY * s.sigmaY)))
                }
            }
        }
        if let clip { v = v.map { min($0, clip) } }
        return v.map(Float.init)
    }

    /// Griglia 8×8 di stelle, distanti 56 px, a partire da (60, 60): adatta a un campo 512×512.
    static func grid(amplitude: Double = 2000, sigmaX: Double = 2, sigmaY: Double = 2) -> [SyntheticStar] {
        (0..<8).flatMap { j in
            (0..<8).map { i in
                SyntheticStar(x: 60 + 56 * Double(i) + 0.3, y: 60 + 56 * Double(j) + 0.3,
                              amplitude: amplitude, sigmaX: sigmaX, sigmaY: sigmaY)
            }
        }
    }
}
