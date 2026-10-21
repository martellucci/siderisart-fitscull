import Foundation

/// Ordinamento per valore di righe della tabella e colonne dei grafici. I valori mancanti (frame non ancora
/// analizzati) vanno in fondo in entrambi i versi; a parità di valore resta l'ordine di ripresa.
public enum RowOrder {
    public static func compare(_ a: (value: Double?, index: Int), _ b: (value: Double?, index: Int),
                               ascending: Bool) -> ComparisonResult {
        switch (a.value, b.value) {
        case let (va?, vb?) where va != vb:
            return (va < vb) == ascending ? .orderedAscending : .orderedDescending
        case (nil, _?): return .orderedDescending
        case (_?, nil): return .orderedAscending
        default:
            return a.index == b.index ? .orderedSame : a.index < b.index ? .orderedAscending : .orderedDescending
        }
    }

    public static func sorted<T>(_ items: [T], ascending: Bool, value: (T) -> Double?, index: (T) -> Int) -> [T] {
        items.map { (item: $0, key: (value: value($0), index: index($0))) }
            .sorted { compare($0.key, $1.key, ascending: ascending) == .orderedAscending }
            .map(\.item)
    }
}
