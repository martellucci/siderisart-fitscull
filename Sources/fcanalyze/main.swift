import FitsCullCore
import Foundation

// Uso: fcanalyze <file.fits | cartella> …   (compilare con -c release per tempi realistici)
let arguments = CommandLine.arguments.dropFirst()
guard !arguments.isEmpty else {
    print("Usage: fcanalyze <file.fits|folder> …")
    exit(1)
}

let extensions: Set<String> = ["fit", "fits", "fts"]
var urls: [URL] = []
for argument in arguments {
    let url = URL(fileURLWithPath: argument)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: argument, isDirectory: &isDirectory) else {
        print("Not found: \(argument)")
        continue
    }
    if isDirectory.boolValue {
        let items = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        urls += items.filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } else {
        urls.append(url)
    }
}

func format(_ value: Double?, _ digits: Int) -> String {
    guard let value, value.isFinite else { return "-" }
    return String(format: "%.\(digits)f", value)
}

print(["file", "type", "exp", "background", "noise", "sat%", "stars", "FWHMpx", "FWHM\"", "ecc", "ms"].joined(separator: "\t"))
for url in urls {
    let start = Date()
    do {
        let (a, _) = try FrameAnalyzer.analyze(url: url, includePreview: false)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        print([url.lastPathComponent, a.meta.imageType.label, format(a.meta.exposure, 0), format(a.background, 1),
               format(a.noise, 1), format(a.saturatedFraction.map { $0 * 100 }, 3), a.stars.map { "\($0.count)" } ?? "-",
               format(a.stars?.fwhm, 2), format(a.stars?.fwhmArcsec, 2), format(a.stars?.eccentricity, 2), "\(ms)"]
            .joined(separator: "\t"))
    } catch {
        let message = (error as? FITSError)?.description ?? error.localizedDescription
        print("\(url.lastPathComponent)\tERROR: \(message)")
    }
}
