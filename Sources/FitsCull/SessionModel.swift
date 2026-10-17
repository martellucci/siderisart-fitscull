import AppKit
import FitsCullCore
import Observation
import SwiftUI

enum FrameStatus: Equatable {
    case pending
    case analyzing
    case done
    case failed(String)
}

struct FrameRecord: Identifiable {
    let id: URL
    /// Posizione cronologica nella cartella (1…n).
    let index: Int
    var file: FrameFile
    var header: FITSHeader?
    var meta: FrameMeta?
    var analysis: FrameAnalysis?
    var status: FrameStatus
    var rejected = false
    var flags: OutlierFlags = []
}

struct Preview: @unchecked Sendable {
    let image: CGImage
    let histogram: DisplayHistogram
}

enum ZoomMode: String, CaseIterable {
    case fit = "Fit"
    case half = "50%"
    case full = "100%"
}

enum ViewMode: String, CaseIterable {
    case review = "Review"
    case session = "Session"
}

enum SortKey: String, CaseIterable {
    case date = "Date"
    case fwhm = "FWHM"
    case stars = "Stars"
    case background = "Background"
}

@MainActor
@Observable
final class SessionModel {
    var folder: URL?
    var records: [FrameRecord] = []
    var selection: URL? {
        didSet { if selection != oldValue { selectionChanged() } }
    }
    var typeFilter: ImageType? = .light {
        didSet {
            refreshSummary()
            let visible = SelectionPolicy.reconcile(selection, visible: visibleRecords.map(\.id))
            if visible != selection { selection = visible }
            pump()
        }
    }
    var sortKey: SortKey = .date
    var viewMode: ViewMode = .review
    var stretchEnabled = true {
        didSet { invalidatePreviews() }
    }
    var linkedChannels = true {
        didSet { invalidatePreviews() }
    }
    /// Adatta: immagine intera; 50%: un pixel dell'anteprima (superpixel) per pixel dello schermo;
    /// 100%: pixel reali del sensore, ricostruiti a piena risoluzione solo per il file corrente.
    var zoom: ZoomMode = .fit {
        didSet {
            if zoom == .full { loadFullResolution() } else { fullResolution = nil }
        }
    }
    var fullResolution: (url: URL, preview: Preview)?
    var fullResolutionLoading: URL?
    var confirmTrashCurrent = false
    /// Mediane per gruppo (tipo + filtro), base delle segnalazioni ⚠︎.
    var summaries: [FrameGroup: SessionSummary] = [:]
    var thresholds = Thresholds()
    /// Soglie delle segnalazioni ⚠︎ (Settings, ⌘,); salvate nelle preferenze.
    var alertSettings = AlertSettings.load() {
        didSet {
            guard alertSettings != oldValue else { return }
            alertSettings.save()
            refreshSummary()
        }
    }
    var previews: [URL: Preview] = [:]
    var loadingMessage: String?
    var errorMessage: String?
    var confirmTrash = false
    var trashFallback: [URL] = []
    var trashFallbackReason: String?

    let concurrency = 3
    let previewRadius = 5
    let cache = MetricsCache(directory: MetricsCache.defaultDirectory())

    @ObservationIgnored private var currentSource: (url: URL, source: PreviewSource)?
    @ObservationIgnored private var analysesInFlight: Set<URL> = []
    @ObservationIgnored private var previewsInFlight: Set<URL> = []
    @ObservationIgnored private var activeJobs = 0
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var renderVersion = 0

    // MARK: - Viste derivate

    func isVisible(_ record: FrameRecord) -> Bool {
        typeFilter == nil || record.meta == nil || record.meta?.imageType == typeFilter
    }

    var visibleRecords: [FrameRecord] {
        let list = records.filter(isVisible)
        switch sortKey {
        case .date:
            return list
        case .fwhm:
            return list.sorted { ($0.analysis?.stars?.fwhm ?? .infinity) < ($1.analysis?.stars?.fwhm ?? .infinity) }
        case .stars:
            return list.sorted { ($0.analysis?.stars?.count ?? -1) > ($1.analysis?.stars?.count ?? -1) }
        case .background:
            return list.sorted { ($0.analysis?.background ?? .infinity) < ($1.analysis?.background ?? .infinity) }
        }
    }

    var selectedRecord: FrameRecord? {
        selection.flatMap { id in records.first { $0.id == id } }
    }

    /// Frame dei grafici della colonna di destra: i light dello stesso filtro del frame selezionato,
    /// in ordine di ripresa (`records` è già cronologico). nil per dark, flat e bias.
    var seriesRecords: (group: FrameGroup, records: [FrameRecord])? {
        guard let meta = selectedRecord?.meta, meta.imageType.hasStars else { return nil }
        let group = FrameGroup(meta)
        let list = records.filter { r in
            if case .failed = r.status { return false }
            return r.meta.map(FrameGroup.init) == group
        }
        return (group, list)
    }

    var rejectedCount: Int { records.filter(\.rejected).count }

    var totalBytes: Int64 { records.reduce(0) { $0 + $1.file.size } }

    var availableTypes: [ImageType] {
        ImageType.allCases.filter { type in records.contains { $0.meta?.imageType == type } }
    }

    // MARK: - Azioni

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func open(_ url: URL) {
        saveCache()
        generation += 1
        let gen = generation
        folder = url
        records = []
        previews = [:]
        currentSource = nil
        analysesInFlight = []
        previewsInFlight = []
        summaries = [:]
        selection = nil
        loadingMessage = "Reading headers…"
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result(catching: { try FolderScanner.scan(url) })
            }.value
            guard gen == generation else { return }
            loadingMessage = nil
            switch result {
            case .failure(let error):
                errorMessage = UserMessage.from(error)
            case .success(let scanned):
                records = scanned.enumerated().map { i, s in
                    let cached = s.meta == nil ? nil : cache.lookup(s.file)
                    let status: FrameStatus = if let e = s.headerError { .failed(e) } else if cached != nil { .done } else { .pending }
                    return FrameRecord(id: s.file.url, index: i + 1, file: s.file, header: s.header, meta: s.meta,
                                       analysis: cached, status: status)
                }
                if records.isEmpty { errorMessage = "No FITS files (.fit, .fits, .fts) in this folder." }
                if let type = typeFilter, !records.contains(where: { $0.meta?.imageType == type }) { typeFilter = nil }
                refreshSummary()
                selection = visibleRecords.first?.id
                pump()
            }
        }
    }

    func move(_ delta: Int) {
        if let target = SelectionPolicy.moved(selection, in: visibleRecords.map(\.id), by: delta) {
            selection = target
        }
    }

    func moveToFirst() { move(Int.min) }

    func moveToLast() { move(Int.max) }

    var positionText: String {
        let visible = visibleRecords.map(\.id)
        guard let p = SelectionPolicy.position(of: selection, in: visible) else { return "– / \(visible.count)" }
        return "\(p.index) / \(p.count)"
    }

    func toggleReject() {
        guard let id = selection else { return }
        update(id) { $0.rejected.toggle() }
    }

    var outOfThresholdCount: Int {
        records.filter { isVisible($0) && ($0.analysis.map { thresholds.violates($0) } ?? false) }.count
    }

    /// Segna come scartati (senza spostare) i file visibili oltre le soglie.
    func markOutOfThreshold() {
        for i in records.indices where isVisible(records[i]) {
            if let a = records[i].analysis, thresholds.violates(a) { records[i].rejected = true }
        }
    }

    func saveCache() {
        try? cache.save()
    }

    /// Rilegge l'header (es. NAS ricollegato) e rimette il file in coda.
    func retry(_ url: URL) {
        Task {
            let header = await Task.detached(priority: .userInitiated) { try? FITSReader.readHeader(url: url) }.value
            update(url) { record in
                if let header {
                    record.header = header
                    record.meta = FrameMeta(header: header)
                    record.status = .pending
                } else {
                    record.status = .failed("file not readable (disk or NAS disconnected?)")
                }
            }
            pump()
        }
    }

    // MARK: - Cestino

    var rejectedBytes: Int64 { records.filter(\.rejected).reduce(0) { $0 + $1.file.size } }

    var trashFallbackBytes: Int64 {
        let pending = Set(trashFallback)
        return records.filter { pending.contains($0.id) }.reduce(0) { $0 + $1.file.size }
    }

    func requestTrashCurrent() {
        if selection != nil { confirmTrashCurrent = true }
    }

    /// Sposta nel Cestino solo il file corrente (dopo conferma) e passa al successivo.
    func performTrashCurrent() {
        guard let url = selection else { return }
        let report = TrashService().moveToTrash([url])
        removeRecords(report.trashed)
        trashFallback = report.trashUnavailable + report.failed.keys.sorted { $0.path < $1.path }
        trashFallbackReason = report.failed.values.first
    }

    func requestTrash() {
        if rejectedCount > 0 { confirmTrash = true }
    }

    func performTrash() {
        let report = TrashService().moveToTrash(records.filter(\.rejected).map(\.id))
        removeRecords(report.trashed)
        trashFallback = report.trashUnavailable + report.failed.keys.sorted { $0.path < $1.path }
        trashFallbackReason = report.failed.values.first
    }

    func moveFallbackToRejectFolder() {
        let report = TrashService().moveToRejectFolder(trashFallback)
        removeRecords(report.done)
        trashFallback = []
        if let reason = report.failed.values.first {
            errorMessage = "Could not move \(report.failed.count) file(s): \(reason)"
        }
    }

    func deleteFallbackPermanently() {
        let report = TrashService().deletePermanently(trashFallback)
        removeRecords(report.done)
        trashFallback = []
        if let reason = report.failed.values.first {
            errorMessage = "Could not delete \(report.failed.count) file(s): \(reason)"
        }
    }

    private func removeRecords(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let gone = Set(urls)
        let list = visibleRecords
        var next = selection
        if let selected = selection, gone.contains(selected), let i = list.firstIndex(where: { $0.id == selected }) {
            next = list[i...].first { !gone.contains($0.id) }?.id ?? list[..<i].last { !gone.contains($0.id) }?.id
        }
        records.removeAll { gone.contains($0.id) }
        for url in urls {
            cache.remove(url)
            previews[url] = nil
        }
        saveCache()
        selection = next
        refreshSummary()
    }

    // MARK: - Scheduling dell'analisi

    private enum Job {
        case analyze(URL, withPreview: Bool)
        case preview(URL)
    }

    private func selectionChanged() {
        if fullResolution?.url != selection { fullResolution = nil }
        loadFullResolution()
        let window = Set(previewWindow())
        previews = previews.filter { window.contains($0.key) }
        if currentSource?.url != selection { currentSource = nil }
        pump()
    }

    private func previewWindow() -> [URL] {
        let list = visibleRecords
        let position = list.firstIndex { $0.id == selection }
        return AnalysisOrder.window(count: list.count, around: position, radius: previewRadius).map { list[$0].id }
    }

    private func analysisQueue() -> [URL] {
        let list = visibleRecords
        let position = list.firstIndex { $0.id == selection }
        let near = AnalysisOrder.indices(count: list.count, around: position).map { list[$0].id }
        return near + records.filter { !isVisible($0) }.map(\.id)
    }

    private func nextJob() -> Job? {
        let lookup = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        let window = previewWindow()
        func needsPreview(_ url: URL) -> Bool {
            previews[url] == nil && !previewsInFlight.contains(url) && !analysesInFlight.contains(url)
        }
        if let selected = selection, let record = lookup[selected], needsPreview(selected) {
            switch record.status {
            case .pending: return .analyze(selected, withPreview: true)
            case .done: return .preview(selected)
            default: break
            }
        }
        for url in analysisQueue() where lookup[url]?.status == .pending && !analysesInFlight.contains(url) {
            return .analyze(url, withPreview: window.contains(url) && needsPreview(url))
        }
        for url in window where lookup[url]?.status == .done && needsPreview(url) {
            return .preview(url)
        }
        return nil
    }

    private func pump() {
        while activeJobs < concurrency, let job = nextJob() { start(job) }
        if activeJobs == 0 { saveCache() }
    }

    private func start(_ job: Job) {
        activeJobs += 1
        let gen = generation
        switch job {
        case .analyze(let url, let withPreview):
            analysesInFlight.insert(url)
            if withPreview { previewsInFlight.insert(url) }
            update(url) { $0.status = .analyzing }
            Task {
                let result = await Task.detached(priority: .userInitiated) {
                    Result(catching: { try FrameAnalyzer.analyze(url: url, includePreview: withPreview) })
                }.value
                self.finishAnalysis(url, result, generation: gen)
            }
        case .preview(let url):
            previewsInFlight.insert(url)
            Task {
                let result = await Task.detached(priority: .userInitiated) {
                    Result(catching: { try FrameAnalyzer.preview(url: url) })
                }.value
                self.finishPreview(url, result, generation: gen)
            }
        }
    }

    private func finishAnalysis(_ url: URL, _ result: Result<(analysis: FrameAnalysis, preview: PreviewSource?), Error>,
                                generation gen: Int) {
        activeJobs -= 1
        guard gen == generation else { pump(); return }
        analysesInFlight.remove(url)
        switch result {
        case .success(let output):
            update(url) {
                $0.analysis = output.analysis
                $0.status = .done
            }
            if let file = records.first(where: { $0.id == url })?.file { cache.store(output.analysis, for: file) }
            refreshSummary()
            if let source = output.preview { render(url, source) } else { previewsInFlight.remove(url) }
        case .failure(let error):
            previewsInFlight.remove(url)
            update(url) { $0.status = .failed(UserMessage.from(error)) }
        }
        pump()
    }

    private func finishPreview(_ url: URL, _ result: Result<PreviewSource, Error>, generation gen: Int) {
        activeJobs -= 1
        guard gen == generation else { pump(); return }
        switch result {
        case .success(let source):
            render(url, source)
        case .failure(let error):
            previewsInFlight.remove(url)
            update(url) { $0.status = .failed(UserMessage.from(error)) }
        }
        pump()
    }

    /// Stretch fuori dal main thread; `url` deve essere già in `previewsInFlight`.
    private func render(_ url: URL, _ source: PreviewSource) {
        if url == selection { currentSource = (url, source) }
        let gen = generation, version = renderVersion
        let stretch = stretchEnabled, linked = linkedChannels
        Task {
            let preview = await Task.detached(priority: .userInitiated) {
                SessionModel.makePreview(source, stretch: stretch, linked: linked)
            }.value
            guard gen == generation else { return }
            previewsInFlight.remove(url)
            if version == renderVersion, let preview,
               SelectionPolicy.keepsPreview(for: url, selection: selection, window: previewWindow()) {
                previews[url] = preview
            }
            pump()
        }
    }

    /// Carica (fuori dal main thread) il file corrente a piena risoluzione quando lo zoom è al 100%.
    private func loadFullResolution() {
        guard zoom == .full, let url = selection, fullResolution?.url != url, fullResolutionLoading != url,
              let record = selectedRecord else { return }
        if case .failed = record.status { return }
        fullResolutionLoading = url
        let gen = generation, version = renderVersion
        let stretch = stretchEnabled, linked = linkedChannels
        Task {
            let preview = await Task.detached(priority: .userInitiated) { () -> Preview? in
                guard let source = try? FrameAnalyzer.fullResolution(url: url) else { return nil }
                return SessionModel.makePreview(source, stretch: stretch, linked: linked)
            }.value
            guard gen == generation else { return }
            if fullResolutionLoading == url { fullResolutionLoading = nil }
            guard url == selection, zoom == .full else { return }
            if version == renderVersion, let preview {
                fullResolution = (url, preview)
            } else if version != renderVersion {
                loadFullResolution()
            }
        }
    }

    nonisolated static func makePreview(_ source: PreviewSource, stretch: Bool, linked: Bool) -> Preview? {
        let stretched = AutoStretch.stretch(source.image, normalization: source.normalization, linked: linked, enabled: stretch)
        guard let image = AutoStretch.cgImage(stretched) else { return nil }
        return Preview(image: image, histogram: DisplayHistogram(stretched, isColor: source.image.isColor))
    }

    private func invalidatePreviews() {
        renderVersion += 1
        previews = [:]
        fullResolution = nil
        loadFullResolution()
        if let current = currentSource, current.url == selection, !previewsInFlight.contains(current.url) {
            previewsInFlight.insert(current.url)
            render(current.url, current.source)
        }
        pump()
    }

    // MARK: - Supporto

    func update(_ url: URL, _ change: (inout FrameRecord) -> Void) {
        guard let i = records.firstIndex(where: { $0.id == url }) else { return }
        change(&records[i])
    }

    func refreshSummary() {
        // Mediane per filtro: con L e Ha nella stessa cartella ognuno si confronta con i suoi.
        let newSummaries = OutlierRules.summaries(records.compactMap(\.analysis))
        var updated = records
        for i in updated.indices {
            if let a = updated[i].analysis, let s = newSummaries[FrameGroup(a.meta)] {
                updated[i].flags = OutlierRules.flags(for: a, in: s, settings: alertSettings)
            } else {
                updated[i].flags = []
            }
        }
        summaries = newSummaries
        records = updated
    }
}
