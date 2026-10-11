public struct PlanarImage: Sendable {
    public let width: Int
    public let height: Int
    /// Pixel del sensore per pixel di uscita lungo ciascun asse (2 per superpixel Bayer, 1 per mono).
    public let binFactor: Int
    /// Un piano (mono) oppure tre (R, G, B).
    public var planes: [[Float]]

    public init(width: Int, height: Int, binFactor: Int, planes: [[Float]]) {
        self.width = width
        self.height = height
        self.binFactor = binFactor
        self.planes = planes
    }

    public var isColor: Bool { planes.count == 3 }

    public func luminance() -> [Float] {
        guard isColor else { return planes[0] }
        var out = [Float](repeating: 0, count: width * height)
        let r = planes[0], g = planes[1], b = planes[2]
        for i in 0..<out.count { out[i] = (r[i] + g[i] + b[i]) / 3 }
        return out
    }
}

public enum FrameDecoder {
    /// Superpixel 2×2 (R, media dei due G, B) a metà risoluzione; mono invariato.
    public static func decode(_ image: FITSImage, pattern: BayerPattern?) -> PlanarImage {
        guard let pattern else {
            return PlanarImage(width: image.width, height: image.height, binFactor: 1, planes: [image.pixels])
        }
        let w = image.width / 2, h = image.height / 2
        let o = pattern.offsets(rowStride: image.width)
        var r = [Float](repeating: 0, count: w * h)
        var g = r
        var b = r
        image.pixels.withUnsafeBufferPointer { src in
            for y in 0..<h {
                for x in 0..<w {
                    let base = 2 * y * image.width + 2 * x
                    let i = y * w + x
                    r[i] = src[base + o.r]
                    g[i] = (src[base + o.g1] + src[base + o.g2]) * 0.5
                    b[i] = src[base + o.b]
                }
            }
        }
        return PlanarImage(width: w, height: h, binFactor: 2, planes: [r, g, b])
    }

    /// Campioni CFA grezzi per colore, per le statistiche: [R, G, B] (G contiene entrambi i verdi) o [L].
    public static func cfaChannels(_ image: FITSImage, pattern: BayerPattern?) -> [[Float]] {
        guard let pattern else { return [image.pixels] }
        let w = image.width / 2, h = image.height / 2
        let o = pattern.offsets(rowStride: image.width)
        var r = [Float](), g = [Float](), b = [Float]()
        r.reserveCapacity(w * h)
        g.reserveCapacity(2 * w * h)
        b.reserveCapacity(w * h)
        image.pixels.withUnsafeBufferPointer { src in
            for y in 0..<h {
                for x in 0..<w {
                    let base = 2 * y * image.width + 2 * x
                    r.append(src[base + o.r])
                    g.append(src[base + o.g1])
                    g.append(src[base + o.g2])
                    b.append(src[base + o.b])
                }
            }
        }
        return [r, g, b]
    }
}
