import CoreGraphics
import Foundation

public struct StretchParams: Sendable, Equatable {
    public var shadows: Double
    public var midtones: Double

    public init(shadows: Double, midtones: Double) {
        self.shadows = shadows
        self.midtones = midtones
    }

    public static let identity = StretchParams(shadows: 0, midtones: 0.5)
}

public struct StretchedImage: Sendable {
    public let width: Int
    public let height: Int
    /// RGBA 8 bit, alfa sempre 255.
    public let rgba: [UInt8]
}

/// Stretch automatico come l'AutoSTF di PixInsight.
public enum AutoStretch {
    public static let targetBackground = 0.25
    public static let shadowsClipping = -2.8

    /// Midtones transfer function.
    public static func mtf(_ m: Double, _ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        return ((m - 1) * x) / ((2 * m - 1) * x - m)
    }

    /// Parametri da mediana e MAD normalizzati in [0, 1].
    public static func params(median: Double, mad: Double) -> StretchParams {
        let shadows = min(max(median + shadowsClipping * 1.4826 * mad, 0), 1)
        guard median > shadows, shadows < 1 else { return .identity }
        let x0 = (median - shadows) / (1 - shadows)
        return StretchParams(shadows: shadows, midtones: mtf(targetBackground, x0))
    }

    public static func stretch(_ image: PlanarImage, normalization: Float, linked: Bool, enabled: Bool) -> StretchedImage {
        let n = image.width * image.height
        let norm = normalization > 0 ? normalization : 1
        var params = Array(repeating: StretchParams.identity, count: image.planes.count)
        if enabled {
            let measured = image.planes.map { plane -> (median: Double, mad: Double) in
                let m = RobustStats.medianAndMAD(plane)
                return (m.median / Double(norm), m.mad / Double(norm))
            }
            if linked {
                let median = measured.map(\.median).reduce(0, +) / Double(measured.count)
                let mad = measured.map(\.mad).reduce(0, +) / Double(measured.count)
                params = Array(repeating: Self.params(median: median, mad: mad), count: measured.count)
            } else {
                params = measured.map { Self.params(median: $0.median, mad: $0.mad) }
            }
        }
        let tables = params.map(lookupTable)
        var rgba = [UInt8](repeating: 255, count: n * 4)
        rgba.withUnsafeMutableBufferPointer { out in
            for (c, plane) in image.planes.enumerated() {
                let table = tables[c]
                plane.withUnsafeBufferPointer { p in
                    for i in 0..<n {
                        let x = p[i].isFinite ? min(max(p[i] / norm, 0), 1) : 0
                        let v = table[Int(x * 65535)]
                        if image.isColor {
                            out[i * 4 + c] = v
                        } else {
                            out[i * 4] = v
                            out[i * 4 + 1] = v
                            out[i * 4 + 2] = v
                        }
                    }
                }
            }
        }
        return StretchedImage(width: image.width, height: image.height, rgba: rgba)
    }

    static func lookupTable(_ p: StretchParams) -> [UInt8] {
        (0..<65536).map { i in
            let x = Double(i) / 65535
            let y = x <= p.shadows ? 0 : mtf(p.midtones, (x - p.shadows) / (1 - p.shadows))
            return UInt8((y * 255).rounded())
        }
    }

    public static func cgImage(_ s: StretchedImage) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(s.rgba) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: s.width, height: s.height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: s.width * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

public struct DisplayHistogram: Sendable, Equatable {
    /// 256 classi per canale visualizzato (3 a colori, 1 mono).
    public let channels: [[Int]]

    public init(_ s: StretchedImage, isColor: Bool) {
        let count = isColor ? 3 : 1
        var bins = Array(repeating: [Int](repeating: 0, count: 256), count: count)
        let n = s.width * s.height
        for i in 0..<n {
            for c in 0..<count { bins[c][Int(s.rgba[i * 4 + c])] += 1 }
        }
        channels = bins
    }
}
