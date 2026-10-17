import FitsCullCore
import Foundation
import Testing

@Suite struct FrameGroupTests {
    @Test func sameTypeAndFilterAreOneGroup() {
        #expect(FrameGroup(imageType: .light, filter: "L") == FrameGroup(imageType: .light, filter: " L "))
        #expect(FrameGroup(imageType: .light, filter: "L") != FrameGroup(imageType: .light, filter: "Ha"))
        #expect(FrameGroup(imageType: .light, filter: "L") != FrameGroup(imageType: .dark, filter: "L"))
        #expect(FrameGroup(imageType: .light, filter: "  ").filter == nil)
    }

    @Test func groupComesFromHeader() throws {
        let lines = HeaderFixtures.asiair + ["FILTER  = 'Ha      '           / Filter used"]
        let meta = FrameMeta(header: try FITSHeader.parse(FITSFixture.header(lines)))
        #expect(FrameGroup(meta) == FrameGroup(imageType: .light, filter: "Ha"))
    }

    /// L e Ha nella stessa cartella: ognuno confrontato con la propria mediana.
    @Test func summariesArePerGroup() throws {
        let l = (0..<6).map { AnalysisFactory.make(background: 1800, stars: 4000 + $0, fwhm: 3.0, filter: "L") }
        let ha = (0..<4).map { AnalysisFactory.make(background: 400, stars: 600 + $0, fwhm: 3.4, filter: "Ha") }
        let summaries = OutlierRules.summaries(l + ha)
        let sl = try #require(summaries[FrameGroup(l[0].meta)])
        let sha = try #require(summaries[FrameGroup(ha[0].meta)])
        #expect(sl.medianStars == 4002.5)
        #expect(sha.medianStars == 601.5)
        #expect(OutlierRules.flags(for: ha[0], in: sha).isEmpty)
        // Con una mediana unica lo stesso Ha risulterebbe "few stars".
        let mixed = try #require(OutlierRules.summary(l + ha))
        #expect(OutlierRules.flags(for: ha[0], in: mixed).contains(.stars))
    }

    /// Nome mostrato sopra i grafici: il filtro, o il tipo se il file non lo indica (camere a colori).
    @Test func labelIsFilterOrType() {
        #expect(FrameGroup(imageType: .light, filter: "OIII").label == "OIII")
        #expect(FrameGroup(imageType: .light, filter: nil).label == "Light")
    }
}
