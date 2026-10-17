import Foundation

/// Frame confrontabili tra loro: stesso tipo e stesso filtro. Con L, R, G, B e Ha nella stessa cartella
/// ogni filtro ha le sue mediane e i suoi grafici (stelle e fondo cambiano molto da un filtro all'altro).
public struct FrameGroup: Hashable, Sendable {
    public let imageType: ImageType
    /// nil se il file non indica il filtro (camere a colori): tutti quei frame formano un solo gruppo.
    public let filter: String?

    public init(imageType: ImageType, filter: String?) {
        self.imageType = imageType
        let trimmed = filter?.trimmingCharacters(in: .whitespaces) ?? ""
        self.filter = trimmed.isEmpty ? nil : trimmed
    }

    public init(_ meta: FrameMeta) {
        self.init(imageType: meta.imageType, filter: meta.filter)
    }

    /// Nome della serie: il filtro, o il tipo se il filtro manca.
    public var label: String { filter ?? imageType.label }
}
