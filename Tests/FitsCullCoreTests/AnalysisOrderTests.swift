import FitsCullCore
import Testing

@Suite struct AnalysisOrderTests {
    @Test func nearestFirst() {
        #expect(AnalysisOrder.indices(count: 7, around: 3) == [3, 4, 2, 5, 1, 6, 0])
        #expect(AnalysisOrder.indices(count: 4, around: 0) == [0, 1, 2, 3])
        #expect(AnalysisOrder.indices(count: 4, around: 3) == [3, 2, 1, 0])
    }

    @Test func noSelectionKeepsOrder() {
        #expect(AnalysisOrder.indices(count: 3, around: nil) == [0, 1, 2])
        #expect(AnalysisOrder.indices(count: 3, around: 9) == [0, 1, 2])
        #expect(AnalysisOrder.indices(count: 0, around: 0).isEmpty)
    }

    @Test func window() {
        #expect(AnalysisOrder.window(count: 7, around: 3, radius: 1) == [3, 4, 2])
        #expect(AnalysisOrder.window(count: 7, around: nil, radius: 1).isEmpty)
    }
}
