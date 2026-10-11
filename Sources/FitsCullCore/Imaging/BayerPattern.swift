public enum BayerPattern: String, Sendable, Codable, CaseIterable {
    case rggb = "RGGB"
    case bggr = "BGGR"
    case grbg = "GRBG"
    case gbrg = "GBRG"

    /// Colore del pixel (0 = R, 1 = G, 2 = B) con origine in alto a sinistra.
    public func color(x: Int, y: Int) -> Int {
        let letter = Array(rawValue)[(y & 1) * 2 + (x & 1)]
        return letter == "R" ? 0 : (letter == "G" ? 1 : 2)
    }

    /// Offset dei campioni R, G, G, B in una cella 2×2 il cui pixel in alto a sinistra ha offset 0.
    public func offsets(rowStride: Int) -> (r: Int, g1: Int, g2: Int, b: Int) {
        var r = 0, b = 0
        var greens: [Int] = []
        for dy in 0..<2 {
            for dx in 0..<2 {
                let offset = dy * rowStride + dx
                switch color(x: dx, y: dy) {
                case 0: r = offset
                case 2: b = offset
                default: greens.append(offset)
                }
            }
        }
        return (r, greens[0], greens[1], b)
    }
}
