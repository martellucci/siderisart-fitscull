/// Ordine di lavoro: prima il file corrente, poi i vicini alternando avanti/indietro.
public enum AnalysisOrder {
    public static func indices(count: Int, around current: Int?) -> [Int] {
        guard count > 0 else { return [] }
        guard let c = current, (0..<count).contains(c) else { return Array(0..<count) }
        var out = [c]
        var d = 1
        while out.count < count {
            if c + d < count { out.append(c + d) }
            if c - d >= 0 { out.append(c - d) }
            d += 1
        }
        return out
    }

    /// Indici entro `radius` dal corrente, nell'ordine di `indices`; vuoto senza selezione.
    public static func window(count: Int, around current: Int?, radius: Int) -> [Int] {
        guard let c = current, (0..<count).contains(c) else { return [] }
        return indices(count: count, around: c).filter { abs($0 - c) <= radius }
    }
}
