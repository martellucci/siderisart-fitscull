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

    /// Media 2×2 di ogni piano (dimensioni dispari troncate), per le anteprime dei mono.
    public static func binned2x2(_ image: PlanarImage) -> PlanarImage {
        let w = image.width / 2, h = image.height / 2
        let planes = image.planes.map { plane -> [Float] in
            var out = [Float](repeating: 0, count: w * h)
            plane.withUnsafeBufferPointer { src in
                for y in 0..<h {
                    for x in 0..<w {
                        let base = 2 * y * image.width + 2 * x
                        out[y * w + x] = (src[base] + src[base + 1] + src[base + image.width]
                                          + src[base + image.width + 1]) * 0.25
                    }
                }
            }
            return out
        }
        return PlanarImage(width: w, height: h, binFactor: image.binFactor * 2, planes: planes)
    }

    /// Ricostruzione bilineare a piena risoluzione (zoom 100%): ogni colore mancante è la media dei
    /// campioni dello stesso colore nell'intorno 3×3. Mono invariato.
    public static func demosaic(_ image: FITSImage, pattern: BayerPattern?) -> PlanarImage {
        let w = image.width, h = image.height
        guard let pattern else {
            return PlanarImage(width: w, height: h, binFactor: 1, planes: [image.pixels])
        }
        let colors = (0..<4).map { pattern.color(x: $0 & 1, y: $0 >> 1) }
        var r = [Float](repeating: 0, count: w * h)
        var g = r
        var b = r
        image.pixels.withUnsafeBufferPointer { src in
            for y in 0..<h {
                for x in 0..<w {
                    var sums: (Float, Float, Float) = (0, 0, 0)
                    var counts: (Float, Float, Float) = (0, 0, 0)
                    for yy in max(y - 1, 0)...min(y + 1, h - 1) {
                        for xx in max(x - 1, 0)...min(x + 1, w - 1) {
                            let v = src[yy * w + xx]
                            switch colors[(yy & 1) * 2 + (xx & 1)] {
                            case 0: sums.0 += v; counts.0 += 1
                            case 1: sums.1 += v; counts.1 += 1
                            default: sums.2 += v; counts.2 += 1
                            }
                        }
                    }
                    let i = y * w + x
                    let own = colors[(y & 1) * 2 + (x & 1)]
                    r[i] = own == 0 ? src[i] : (counts.0 > 0 ? sums.0 / counts.0 : 0)
                    g[i] = own == 1 ? src[i] : (counts.1 > 0 ? sums.1 / counts.1 : 0)
                    b[i] = own == 2 ? src[i] : (counts.2 > 0 ? sums.2 / counts.2 : 0)
                }
            }
        }
        return PlanarImage(width: w, height: h, binFactor: 1, planes: [r, g, b])
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
