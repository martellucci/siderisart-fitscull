import FitsCullCore
import SwiftUI

/// Finestra Settings (⌘,): soglie delle segnalazioni ⚠︎. Le modifiche si applicano subito alla sessione aperta.
struct SettingsView: View {
    @Environment(SessionModel.self) private var model

    var body: some View {
        let settings = Binding(get: { model.alertSettings }, set: { model.alertSettings = $0.clamped() })
        Form {
            Section("Background") {
                Toggle("Flag high background", isOn: settings.backgroundEnabled)
                Group {
                    row("Above session median by", settings.backgroundExcessPercent, unit: "%")
                    row("And above", settings.minBackgroundADU, unit: "ADU")
                }
                .disabled(!settings.wrappedValue.backgroundEnabled)
            }
            Section("Stars") {
                Toggle("Flag few stars", isOn: settings.starsEnabled)
                row("Fewer than", settings.starsMinPercent, unit: "% of session median")
                    .disabled(!settings.wrappedValue.starsEnabled)
            }
            Section("FWHM") {
                Toggle("Flag high FWHM", isOn: settings.fwhmEnabled)
                row("Above session median by", settings.fwhmExcessPercent, unit: "%")
                    .disabled(!settings.wrappedValue.fwhmEnabled)
            }
            Section {
                Toggle("Flag elongated stars", isOn: settings.eccentricityEnabled)
                row("Eccentricity above", settings.maxEccentricity, unit: "")
                    .disabled(!settings.wrappedValue.eccentricityEnabled)
            } header: {
                Text("Eccentricity")
            } footer: {
                Text("FitsCull reads eccentricity about 6–12% higher than PixInsight: 0.75 here is about 0.67–0.70 there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Text("Flags only highlight frames (⚠︎); nothing is rejected automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore Defaults") { model.alertSettings = .defaults }
                        .disabled(model.alertSettings == .defaults)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ label: String, _ value: Binding<Double>, unit: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField(label, value: value, format: .number.precision(.fractionLength(0...2)))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}
