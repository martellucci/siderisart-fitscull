import Foundation

public struct StarMetrics: Sendable, Codable, Equatable {
    public var count: Int
    /// Half-flux radius mediano, in pixel dell'immagine analizzata.
    public var hfr: Double?
    /// FWHM mediana da momenti secondi, in pixel dell'immagine analizzata.
    public var fwhm: Double?
    public var fwhmArcsec: Double?
    public var eccentricity: Double?

    public init(count: Int, hfr: Double?, fwhm: Double?, fwhmArcsec: Double?, eccentricity: Double?) {
        self.count = count
        self.hfr = hfr
        self.fwhm = fwhm
        self.fwhmArcsec = fwhmArcsec
        self.eccentricity = eccentricity
    }

    public static let none = StarMetrics(count: 0, hfr: nil, fwhm: nil, fwhmArcsec: nil, eccentricity: nil)
}

public struct DetectedStar: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var flux: Double
    public var hfr: Double
    public var fwhm: Double
    public var eccentricity: Double
}

public enum StarDetector {
    public static let tileSize = 64
    public static let sigmaThreshold: Float = 5
    public static let minArea = 3
    public static let maxArea = 2000
    /// Sulla luminanza (media R/G/B) una stella è satura sopra il 95% del massimo rappresentabile.
    public static let saturationRatio: Float = 0.95

    public static func detect(_ v: [Float], width: Int, height: Int, saturationLevel: Float?,
                              arcsecPerPixel: Double?) -> StarMetrics {
        let stars = findStars(v, width: width, height: height, saturationLevel: saturationLevel)
        guard !stars.isEmpty else { return .none }
        let fwhm = RobustStats.exactMedian(stars.map(\.fwhm))
        return StarMetrics(count: stars.count,
                           hfr: RobustStats.exactMedian(stars.map(\.hfr)),
                           fwhm: fwhm,
                           fwhmArcsec: arcsecPerPixel.map { $0 * fwhm },
                           eccentricity: RobustStats.exactMedian(stars.map(\.eccentricity)))
    }

    public static func findStars(_ v: [Float], width: Int, height: Int, saturationLevel: Float?) -> [DetectedStar] {
        guard width >= 16, height >= 16, v.count == width * height else { return [] }
        let background = backgroundMap(v, width: width, height: height)
        var residual = [Float](repeating: 0, count: v.count)
        for i in 0..<v.count { residual[i] = v[i].isFinite ? v[i] - background[i] : 0 }
        let sigma = Float(1.4826 * RobustStats.medianAndMAD(residual).mad)
        guard sigma > 0, sigma.isFinite else { return [] }
        let threshold = sigmaThreshold * sigma

        var visited = [Bool](repeating: false, count: v.count)
        var stack: [Int] = []
        var stars: [DetectedStar] = []
        for start in 0..<v.count where !visited[start] && residual[start] > threshold {
            visited[start] = true
            stack.append(start)
            var area = 0
            var peak = start
            var touchesBorder = false
            while let i = stack.popLast() {
                area += 1
                if residual[i] > residual[peak] { peak = i }
                let x = i % width, y = i / width
                if x == 0 || y == 0 || x == width - 1 || y == height - 1 { touchesBorder = true }
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                        let j = ny * width + nx
                        if !visited[j] && residual[j] > threshold {
                            visited[j] = true
                            stack.append(j)
                        }
                    }
                }
            }
            guard area >= minArea, area <= maxArea, !touchesBorder else { continue }
            if let level = saturationLevel, v[peak] >= level * saturationRatio { continue }
            if let star = measure(residual, width: width, height: height, peak: peak, area: area) {
                stars.append(star)
            }
        }
        return stars
    }

    /// Centroide, momenti secondi (FWHM, eccentricità) e half-flux radius su una finestra circolare.
    static func measure(_ r: [Float], width: Int, height: Int, peak: Int, area: Int) -> DetectedStar? {
        let px = peak % width, py = peak / width
        let radius = max(3.0, 2.5 * (Double(area) / .pi).squareRoot())
        let reach = Int(radius.rounded(.up))
        guard px - reach >= 0, py - reach >= 0, px + reach < width, py + reach < height else { return nil }
        let radius2 = radius * radius

        var flux = 0.0, sx = 0.0, sy = 0.0
        for y in (py - reach)...(py + reach) {
            for x in (px - reach)...(px + reach) {
                let dx = Double(x - px), dy = Double(y - py)
                guard dx * dx + dy * dy <= radius2 else { continue }
                let w = Double(r[y * width + x])
                flux += w
                sx += w * Double(x)
                sy += w * Double(y)
            }
        }
        guard flux > 0 else { return nil }
        let cx = sx / flux, cy = sy / flux

        // Pixel della finestra rispetto al centroide: (dx, dy, valore).
        var pixels: [(dx: Double, dy: Double, w: Double)] = []
        var total = 0.0, firstHalf = 0.0
        for y in (py - reach)...(py + reach) {
            for x in (px - reach)...(px + reach) {
                let dx = Double(x) - cx, dy = Double(y) - cy
                guard dx * dx + dy * dy <= radius2 else { continue }
                let w = Double(r[y * width + x])
                total += w
                firstHalf += w * (dx * dx + dy * dy) / 2
                pixels.append((dx, dy, w))
            }
        }
        guard total > 0, firstHalf > 0 else { return nil }

        // Momenti pesati con una gaussiana circolare adattiva (varianza `window`), che attenua il rumore
        // delle code; per una stella gaussiana l'effetto del peso si rimuove esattamente:
        // λ_stella = λ_misurato · window / (window − λ_misurato).
        var window = firstHalf / total
        var major = 0.0, minor = 0.0
        for _ in 0..<4 {
            var sum = 0.0, mxx = 0.0, myy = 0.0, mxy = 0.0
            for p in pixels {
                let w = p.w * exp(-(p.dx * p.dx + p.dy * p.dy) / (2 * window))
                sum += w
                mxx += w * p.dx * p.dx
                myy += w * p.dy * p.dy
                mxy += w * p.dx * p.dy
            }
            guard sum > 0 else { return nil }
            mxx /= sum
            myy /= sum
            mxy /= sum
            let mean = (mxx + myy) / 2
            let spread = (((mxx - myy) / 2) * ((mxx - myy) / 2) + mxy * mxy).squareRoot()
            let measuredMajor = mean + spread, measuredMinor = mean - spread
            guard measuredMinor > 0, measuredMajor < 0.95 * window else { return nil }
            major = measuredMajor * window / (window - measuredMajor)
            minor = measuredMinor * window / (window - measuredMinor)
            window = (major + minor) / 2
        }
        let half = (major + minor) / 2
        let profile = pixels.map { (d: ($0.dx * $0.dx + $0.dy * $0.dy).squareRoot(), w: $0.w) }.sorted { $0.d < $1.d }

        var accumulated = 0.0, previousDistance = 0.0
        var hfr = profile.last?.d ?? 0
        for p in profile {
            if accumulated + p.w >= total / 2, p.w > 0 {
                hfr = previousDistance + (total / 2 - accumulated) / p.w * (p.d - previousDistance)
                break
            }
            accumulated += p.w
            previousDistance = p.d
        }
        return DetectedStar(x: cx, y: cy, flux: total, hfr: hfr, fwhm: 2.3548 * half.squareRoot(),
                            eccentricity: (1 - minor / major).squareRoot())
    }

    /// Fondo per tasselli (mediana campionata a passo 2) con interpolazione/estrapolazione bilineare.
    static func backgroundMap(_ v: [Float], width: Int, height: Int) -> [Float] {
        let gx = max(1, width / tileSize), gy = max(1, height / tileSize)
        let tw = width / gx, th = height / gy
        var grid = [Float](repeating: 0, count: gx * gy)
        var samples: [Float] = []
        for ty in 0..<gy {
            for tx in 0..<gx {
                samples.removeAll(keepingCapacity: true)
                let x0 = tx * tw, y0 = ty * th
                let x1 = tx == gx - 1 ? width : x0 + tw
                let y1 = ty == gy - 1 ? height : y0 + th
                for y in stride(from: y0, to: y1, by: 2) {
                    for x in stride(from: x0, to: x1, by: 2) {
                        let value = v[y * width + x]
                        if value.isFinite { samples.append(value) }
                    }
                }
                samples.sort()
                grid[ty * gx + tx] = samples.isEmpty ? 0 : samples[samples.count / 2]
            }
        }

        func axis(_ p: Int, tile: Int, count: Int) -> (i0: Int, i1: Int, w: Float) {
            guard count > 1 else { return (0, 0, 0) }
            let f = (Double(p) + 0.5) / Double(tile) - 0.5
            let i0 = min(max(Int(f.rounded(.down)), 0), count - 2)
            return (i0, i0 + 1, Float(f - Double(i0)))
        }
        let columns = (0..<width).map { axis($0, tile: tw, count: gx) }
        var out = [Float](repeating: 0, count: v.count)
        for y in 0..<height {
            let row = axis(y, tile: th, count: gy)
            for x in 0..<width {
                let col = columns[x]
                let top = grid[row.i0 * gx + col.i0] * (1 - col.w) + grid[row.i0 * gx + col.i1] * col.w
                let bottom = grid[row.i1 * gx + col.i0] * (1 - col.w) + grid[row.i1 * gx + col.i1] * col.w
                out[y * width + x] = top * (1 - row.w) + bottom * row.w
            }
        }
        return out
    }
}
