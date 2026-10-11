import Foundation

/// Regole su selezione e anteprime condivise dal modello dell'app.
public enum SelectionPolicy {
    /// Mantiene la selezione se è tra i file visibili, altrimenti passa al primo visibile.
    public static func reconcile(_ selection: URL?, visible: [URL]) -> URL? {
        if let selection, visible.contains(selection) { return selection }
        return visible.first
    }

    /// Un'anteprima appena calcolata si conserva se è del file selezionato o nella finestra dei vicini.
    public static func keepsPreview(for url: URL, selection: URL?, window: [URL]) -> Bool {
        url == selection || window.contains(url)
    }
}
