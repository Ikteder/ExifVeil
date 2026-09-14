import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selection: PhotosPickerItem?
    @State private var sourceData: Data?
    @State private var report: PrivacyReport?
    @State private var exportURL: URL?
    @State private var isBusy = false
    @State private var status = "Choose one photo to inspect its embedded metadata."

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    introCard
                    pickerCard
                    if let sourceData {
                        preview(data: sourceData)
                    }
                    if let report {
                        reportCard(report)
                    }
                    privacyCard
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ExifVeil")
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("See what the pixels do not show", systemImage: "eye.trianglebadge.exclamationmark")
                .font(.title2.bold())
            Text("ExifVeil finds known location, capture-time, device, author, and note fields. It can create a separate copy without those fields.")
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var pickerCard: some View {
        let pickerTitle = sourceData == nil ? "Choose photo" : "Choose another photo"
        return VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $selection, matching: .images) {
                Label(pickerTitle, systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy)

            HStack(alignment: .top, spacing: 8) {
                if isBusy { ProgressView().controlSize(.small) }
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .cardStyle()
    }

    private func preview(data: Data) -> some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel("Selected photo preview")
            }
        }
    }

    private func reportCard(_ report: PrivacyReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(report.headline).font(.headline)
                    Text("\(report.findings.count) known sensitive fields among \(report.metadataLeafCount) metadata values")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(report.riskScore)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .accessibilityLabel("Privacy signal \(report.riskScore) out of 100")
            }

            if report.findings.isEmpty {
                Label("Nothing in ExifVeil's known sensitive-key list was found.", systemImage: "checkmark.shield")
                    .foregroundStyle(.green)
            } else {
                ForEach(report.findings) { finding in
                    FindingRow(finding: finding)
                }
            }

            Button(action: sanitize) {
                Label("Create sanitized copy", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .controlSize(.large)
            .disabled(sourceData == nil || isBusy)

            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Share sanitized copy", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Opens the system share sheet for the new sanitized file")
            }
        }
        .cardStyle()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Local and non-destructive", systemImage: "lock.shield")
                .font(.headline)
            Text("The picker provides only the selected image. ExifVeil has no network code, does not modify the original, and shares only after you tap Share.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("No findings is not proof of anonymity. Visible content, filenames, edits, and downstream service behavior can still reveal information.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        isBusy = true
        exportURL = nil
        status = "Reading the selected photo locally..."
        defer { isBusy = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                status = "The picker did not return readable image bytes."
                sourceData = nil
                report = nil
                return
            }
            let inspection = try MetadataInspector().inspect(data: data)
            sourceData = data
            report = inspection
            status = "Inspection complete. Review findings before creating a copy."
        } catch {
            sourceData = nil
            report = nil
            status = error.localizedDescription
        }
    }

    private func sanitize() {
        guard let sourceData else { return }
        isBusy = true
        exportURL = nil
        status = "Creating and validating a new copy..."

        Task.detached(priority: .userInitiated) {
            do {
                let result = try ImageSanitizer().sanitize(data: sourceData)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ExifVeil-\(UUID().uuidString)")
                    .appendingPathExtension(result.suggestedFileExtension)
                try result.data.write(to: url, options: .atomic)
                await MainActor.run {
                    exportURL = url
                    status = "Sanitized copy validated: 0 known sensitive fields remain."
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    status = error.localizedDescription
                    isBusy = false
                }
            }
        }
    }
}

private struct FindingRow: View {
    let finding: MetadataFinding

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(finding.title).font(.subheadline.bold())
                    Spacer()
                    Text(finding.severity.label)
                        .font(.caption2.bold())
                        .foregroundStyle(color)
                }
                Text(finding.displayValue)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Text(finding.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch finding.severity {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }

    private var icon: String {
        switch finding.category {
        case .location: "location.fill"
        case .captureTime: "clock.fill"
        case .device: "camera.fill"
        case .authorship: "person.crop.circle.fill"
        case .embeddedNotes: "text.bubble.fill"
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
