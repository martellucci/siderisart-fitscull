import FitsCullCore
import Foundation
import Testing

@Suite struct SelectionPolicyTests {
    static let a = URL(fileURLWithPath: "/s/a.fits")
    static let b = URL(fileURLWithPath: "/s/b.fits")

    @Test func keepsVisibleSelection() {
        #expect(SelectionPolicy.reconcile(Self.b, visible: [Self.a, Self.b]) == Self.b)
    }

    @Test func hiddenSelectionMovesToFirstVisible() {
        #expect(SelectionPolicy.reconcile(Self.b, visible: [Self.a]) == Self.a)
        #expect(SelectionPolicy.reconcile(Self.b, visible: []) == nil)
    }

    /// Selezione nascosta dal filtro: la finestra dei vicini è vuota, ma l'anteprima del file
    /// selezionato va conservata, altrimenti verrebbe ricalcolata all'infinito.
    @Test func selectedPreviewIsKeptEvenOutsideWindow() {
        #expect(SelectionPolicy.keepsPreview(for: Self.b, selection: Self.b, window: []))
        #expect(SelectionPolicy.keepsPreview(for: Self.a, selection: Self.b, window: [Self.a]))
        #expect(!SelectionPolicy.keepsPreview(for: Self.a, selection: Self.b, window: [Self.b]))
    }
}
