import FitsCullCore
import SwiftUI

struct HistogramView: View {
    let histogram: DisplayHistogram

    var body: some View {
        Canvas { context, size in
            let colors: [Color] = histogram.channels.count == 3 ? [.red, .green, .blue] : [.gray]
            for (c, bins) in histogram.channels.enumerated() {
                let peak = log(Double((bins.max() ?? 0) + 1))
                guard peak > 0 else { continue }
                var path = Path()
                for (i, count) in bins.enumerated() {
                    let point = CGPoint(x: size.width * CGFloat(i) / 255,
                                        y: size.height * (1 - CGFloat(log(Double(count + 1)) / peak)))
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color(colors[c].opacity(0.85)), lineWidth: 1)
            }
        }
        .background(Color.black.opacity(0.85), in: .rect(cornerRadius: 4))
    }
}
