import Foundation

/// Regole su selezione e anteprime condivise dal modello dell'app.
public enum SelectionPolicy {
    /// Mantiene la selezione se è tra i file visibili, altrimenti passa al primo visibile.
    public static func reconcile(_ selection: URL?, visible: [URL]) -> URL? {
        if let selection, visible.contains(selection) { return selection }
        return visible.first
    }

    /// File a distanza `delta` dalla selezione, fermandosi al primo/ultimo (Int.min/Int.max = estremi).
    public static func moved(_ selection: URL?, in visible: [URL], by delta: Int) -> URL? {
        guard !visible.isEmpty else { return nil }
        let current = selection.flatMap { visible.firstIndex(of: $0) } ?? 0
        let (target, overflow) = current.addingReportingOverflow(delta)
        let index = overflow ? (delta > 0 ? visible.count - 1 : 0) : min(max(target, 0), visible.count - 1)
        return visible[index]
    }

    /// Posizione 1-based della selezione tra i file visibili, per l'indicatore "12 / 124".
    public static func position(of selection: URL?, in visible: [URL]) -> (index: Int, count: Int)? {
        guard let selection, let i = visible.firstIndex(of: selection) else { return nil }
        return (i + 1, visible.count)
    }

    /// Un'anteprima appena calcolata si conserva se è del file selezionato o nella finestra dei vicini.
    public static func keepsPreview(for url: URL, selection: URL?, window: [URL]) -> Bool {
        url == selection || window.contains(url)
    }
}
