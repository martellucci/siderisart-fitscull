import FitsCullCore
import Foundation
import Testing

@Suite struct RowOrderTests {
    struct Item: Equatable {
        let index: Int
        let value: Double?
    }

    static let items: [Item] = [Item(index: 1, value: 3), Item(index: 2, value: nil), Item(index: 3, value: 1),
                                Item(index: 4, value: 2), Item(index: 5, value: 1)]

    static func indices(ascending: Bool) -> [Int] {
        RowOrder.sorted(items, ascending: ascending, value: \.value, index: \.index).map(\.index)
    }

    /// Clic sull'intestazione della tabella: a parità di valore resta l'ordine di ripresa,
    /// i frame senza valore (non ancora analizzati) restano in fondo in entrambi i versi.
    @Test func ascendingKeepsCaptureOrderOnTiesAndGapsLast() {
        #expect(Self.indices(ascending: true) == [3, 5, 4, 1, 2])
    }

    @Test func descendingKeepsCaptureOrderOnTiesAndGapsLast() {
        #expect(Self.indices(ascending: false) == [1, 4, 3, 5, 2])
    }

    @Test func compareMatchesSorting() {
        let a = (value: Double?(1), index: 3), b = (value: Double?(2), index: 1), gap = (value: Double?.none, index: 0)
        #expect(RowOrder.compare(a, b, ascending: true) == .orderedAscending)
        #expect(RowOrder.compare(a, b, ascending: false) == .orderedDescending)
        #expect(RowOrder.compare(gap, a, ascending: true) == .orderedDescending)
        #expect(RowOrder.compare(gap, a, ascending: false) == .orderedDescending)
        #expect(RowOrder.compare(a, a, ascending: true) == .orderedSame)
    }
}
