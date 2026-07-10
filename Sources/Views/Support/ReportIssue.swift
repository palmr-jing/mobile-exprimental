import SwiftUI
import UIKit
import FirebaseFirestore
import FirebaseStorage

// "Report an issue" — a per-tab affordance that snapshots the current screen,
// lets the user describe what's wrong, and files a ticket into the
// `mobile commander` project (commander_tasks) with the screenshot attached, so
// the fleet/dashboard sees exactly what the reporter saw.

// Captures the key window as an image. Must be called BEFORE presenting the
// report sheet so the shot shows the tab, not the sheet.
enum ScreenCapture {
    static func current() -> UIImage? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        guard let window else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }
}

// Presented from the app root (above the TabView) so the sheet is shared by every
// tab, while the button lives in each tab's toolbar.
@MainActor
final class ReportIssuePresenter: ObservableObject {
    @Published var draft: Draft?

    struct Draft: Identifiable {
        let id = UUID()
        let screenshot: UIImage?
        let tab: String
    }

    private let db = Firestore.firestore()

    // Snapshot now, then open the sheet.
    func start(tab: String) {
        draft = Draft(screenshot: ScreenCapture.current(), tab: tab)
    }

    // File the ticket: create the task (attachments_pending while the screenshot
    // uploads), push the PNG to Storage, then attach it — the exact shape the web
    // TaskForm writes and the worker's downloadAttachments expects.
    func submit(description: String, tab: String, screenshot: UIImage?) async throws {
        let nextId = try await nextNumId()
        let png = screenshot?.pngData()

        var data: [String: Any] = [
            "num_id": nextId,
            "project": "mobile commander",
            "path": "~/repos/mobile-exprimental",
            "task": Self.title(from: description),
            "description": Self.body(description: description, tab: tab),
            "status": "pending",
            "priority": 5,
            "depends_on": [],
            "allow_parallel": false,
            "assigned_worker": "palmr-m24",   // only m24 can build iOS
            "source": "ios-report",
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp(),
        ]
        if png != nil { data["attachments_pending"] = true }

        let ref = try await db.collection("commander_tasks").addDocument(data: data)
        guard let png else { return }

        do {
            let path = "task-attachments/\(nextId)/screenshot.png"
            let storageRef = Storage.storage().reference(withPath: path)
            let meta = StorageMetadata()
            meta.contentType = "image/png"
            _ = try await storageRef.putDataAsync(png, metadata: meta)
            let url = try await storageRef.downloadURL()
            try await ref.updateData([
                "attachments": [[
                    "name": "screenshot.png",
                    "size": png.count,
                    "type": "image/png",
                    "storage_path": path,
                    "download_url": url.absoluteString,
                ]],
                "attachments_pending": false,
                "updated_at": FieldValue.serverTimestamp(),
            ])
        } catch {
            // Don't strand the task on attachments_pending if the upload fails —
            // let it run without the shot, but record why.
            try? await ref.updateData([
                "attachments_pending": false,
                "attachments_error": error.localizedDescription,
            ])
            throw error
        }
    }

    // Fresh max(num_id)+1 (matches the web) rather than trusting an in-memory list.
    private func nextNumId() async throws -> Int {
        let snap = try await db.collection("commander_tasks")
            .order(by: "num_id", descending: true).limit(to: 1).getDocuments()
        return ((snap.documents.first?.data()["num_id"] as? Int) ?? 0) + 1
    }

    nonisolated static func title(from description: String) -> String {
        let firstLine = description.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n").first.map(String.init) ?? ""
        let base = firstLine.isEmpty ? "Issue report" : firstLine
        let clipped = base.count > 80 ? String(base.prefix(80)) + "…" : base
        return "[iOS] \(clipped)"
    }

    nonisolated static func body(description: String, tab: String) -> String {
        """
        Reported from the Emma iOS app (\(tab) tab).

        \(description.trimmingCharacters(in: .whitespacesAndNewlines))

        A screenshot of the screen at report time is attached (attachments/screenshot.png).
        """
    }
}

// Toolbar button each tab adds; opens the shared report sheet for its tab.
struct ReportIssueButton: View {
    @EnvironmentObject private var reporter: ReportIssuePresenter
    let tab: String

    var body: some View {
        Button {
            reporter.start(tab: tab)
        } label: {
            Image(systemName: "exclamationmark.bubble")
        }
        .accessibilityLabel("Report an issue")
        .accessibilityIdentifier("report-issue")
    }
}

// The report sheet: screenshot preview + description + Report.
struct ReportIssueView: View {
    let draft: ReportIssuePresenter.Draft
    @EnvironmentObject private var reporter: ReportIssuePresenter
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var done = false

    private var canSubmit: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !submitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What went wrong?") {
                    TextField("Describe the issue…", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("report-description")
                }
                if let shot = draft.screenshot {
                    Section("Screenshot") {
                        Image(uiImage: shot)
                            .resizable().scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Colors.border, lineWidth: 0.5))
                    }
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
            }
            .navigationTitle("Report an issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if submitting { ProgressView() } else { Text("Report") }
                    }
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("report-submit")
                }
            }
            .alert("Thanks — reported", isPresented: $done) {
                Button("Done") { dismiss() }
            } message: {
                Text("Filed a ticket to the mobile commander project with your screenshot.")
            }
        }
    }

    private func submit() {
        submitting = true
        errorMessage = nil
        let shot = draft.screenshot
        let tab = draft.tab
        let text = description
        Task {
            do {
                try await reporter.submit(description: text, tab: tab, screenshot: shot)
                done = true
            } catch {
                errorMessage = "Couldn't file the report: \(error.localizedDescription)"
            }
            submitting = false
        }
    }
}
