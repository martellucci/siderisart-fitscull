import FitsCullCore
import SwiftUI

/// Conversione in blocco: tutti i file di un tipo della cartella scelta diventano copie di un altro tipo.
struct ConvertFolderView: View {
    @Environment(SessionModel.self) private var model
    let folder: URL

    @State private var counts: [ImageType: Int]?
    @State private var source: ImageType = .light
    @State private var target: ImageType = .dark
    @State private var running = false
    @State private var report: FrameTypeConversion.Report?
    @State private var error: String?

    private var sourceCount: Int { counts?[source] ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Convert Frame Type", systemImage: "arrow.triangle.2.circlepath")
                .font(.title3.bold())
            Text(folder.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            if let error {
                Text(error).foregroundStyle(.red)
            } else if let report {
                summary(report)
            } else if let counts {
                form(counts)
            } else {
                ProgressView("Reading headers…").controlSize(.small)
            }
            HStack {
                Spacer()
                if report == nil && error == nil {
                    Button("Cancel", role: .cancel) { close() }
                        .keyboardShortcut(.cancelAction)
                    Button("Convert \(Self.files(sourceCount, capitalized: true))") { convert() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(running || sourceCount == 0 || source == target)
                } else {
                    Button("Done") { close() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 480)
        .task { await load() }
        .onChange(of: source) { if target == source { target = FrameTypeConversion.types.first { $0 != source } ?? target } }
    }

    private func form(_ counts: [ImageType: Int]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("From").gridColumnAlignment(.trailing)
                    Picker("From", selection: $source) {
                        ForEach(FrameTypeConversion.types, id: \.self) { type in
                            Text("\(type.label) (\(counts[type] ?? 0))").tag(type)
                        }
                    }
                    .labelsHidden().fixedSize()
                }
                GridRow {
                    Text("To")
                    Picker("To", selection: $target) {
                        ForEach(FrameTypeConversion.types.filter { $0 != source }, id: \.self) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
            }
            Text(sourceCount == 0 ? "No \(source.label) frames in this folder."
                 : "Each \(source.label) file gets a \(target.label) copy in the same folder, e.g. \"\(example)\". The originals are not changed; other types are left alone.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if running { ProgressView().controlSize(.small) }
        }
    }

    private var example: String {
        FrameTypeConversion.fileName("\(source.label)_0001.fit", from: source, to: target)
    }

    @ViewBuilder
    private func summary(_ report: FrameTypeConversion.Report) -> some View {
        Text("\(Self.files(report.converted.count)) converted to \(target.label).")
        if !report.skipped.isEmpty {
            Text("\(Self.files(report.skipped.count)) skipped: a file with the new name already exists.")
                .foregroundStyle(.orange)
        }
        if !report.failed.isEmpty {
            Text("\(Self.files(report.failed.count)) failed: \(report.failed.values.first ?? "")").foregroundStyle(.red)
        }
    }

    private static func files(_ n: Int, capitalized: Bool = false) -> String {
        let word = n == 1 ? "file" : "files"
        return "\(n) " + (capitalized ? word.capitalized : word)
    }

    private func load() async {
        let folder = folder
        let result = await Task.detached(priority: .userInitiated) {
            Result(catching: { try FrameTypeConversion.count(in: folder) })
        }.value
        switch result {
        case .success(let counts):
            self.counts = counts
            if let first = FrameTypeConversion.types.first(where: { (counts[$0] ?? 0) > 0 }) { source = first }
        case .failure(let error):
            self.error = UserMessage.from(error)
        }
    }

    private func convert() {
        running = true
        let folder = folder, source = source, target = target
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result(catching: {
                    FrameTypeConversion.convertAll(try FrameTypeConversion.candidates(in: folder, of: source), to: target)
                })
            }.value
            running = false
            switch result {
            case .success(let report): self.report = report
            case .failure(let error): self.error = UserMessage.from(error)
            }
            model.conversionFinished(in: folder)
        }
    }

    private func close() {
        model.conversionFolder = nil
    }
}
