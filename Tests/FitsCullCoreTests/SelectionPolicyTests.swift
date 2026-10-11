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

    static let c = URL(fileURLWithPath: "/s/c.fits")

    @Test func movesWithinBounds() {
        let list = [Self.a, Self.b, Self.c]
        #expect(SelectionPolicy.moved(Self.b, in: list, by: 1) == Self.c)
        #expect(SelectionPolicy.moved(Self.c, in: list, by: 1) == Self.c)
        #expect(SelectionPolicy.moved(Self.a, in: list, by: -1) == Self.a)
        #expect(SelectionPolicy.moved(Self.a, in: list, by: Int.max) == Self.c)
        #expect(SelectionPolicy.moved(Self.c, in: list, by: Int.min) == Self.a)
        #expect(SelectionPolicy.moved(nil, in: list, by: 1) == Self.b)
        #expect(SelectionPolicy.moved(Self.a, in: [], by: 1) == nil)
    }

    @Test func positionIsOneBased() {
        #expect(SelectionPolicy.position(of: Self.b, in: [Self.a, Self.b, Self.c])?.index == 2)
        #expect(SelectionPolicy.position(of: Self.b, in: [Self.a, Self.b, Self.c])?.count == 3)
        #expect(SelectionPolicy.position(of: Self.b, in: [Self.a]) == nil)
    }

    /// Selezione nascosta dal filtro: la finestra dei vicini è vuota, ma l'anteprima del file
    /// selezionato va conservata, altrimenti verrebbe ricalcolata all'infinito.
    @Test func selectedPreviewIsKeptEvenOutsideWindow() {
        #expect(SelectionPolicy.keepsPreview(for: Self.b, selection: Self.b, window: []))
        #expect(SelectionPolicy.keepsPreview(for: Self.a, selection: Self.b, window: [Self.a]))
        #expect(!SelectionPolicy.keepsPreview(for: Self.a, selection: Self.b, window: [Self.b]))
    }
}
