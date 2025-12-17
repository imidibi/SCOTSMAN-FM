//
//  AssessmentsHubView.swift
//  SalesDiver
//
//  Created by Ian Miller on 11/11/25.
//

import SwiftUI

struct AssessmentsHubView: View {
    @State private var assessments: [AssessmentDefinition] = []
    @State private var showBuilder = false

    // Import/Export state
    @State private var isShowingImportPicker = false
    @State private var isShowingExportPicker = false
    @State private var exportSelection: Set<UUID> = []
    @State private var importErrorMessage: String? = nil
    @State private var isShowingErrorAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Saved Assessments")) {
                    ForEach(assessments) { def in
                        NavigationLink(destination: AssessmentBuilderView(existingDefinition: def)) {
                            Text(def.title)
                        }
                    }
                    .onDelete(perform: deleteAssessments)
                }
            }
            .navigationTitle("Assessments")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // Import/Export menu
                        Menu {
                            Button {
                                isShowingImportPicker = true
                            } label: {
                                Label("Import Template (CSV)…", systemImage: "tray.and.arrow.down")
                            }
                            Button {
                                exportSelection = []
                                isShowingExportPicker = true
                            } label: {
                                Label("Export Templates (CSV)…", systemImage: "square.and.arrow.up")
                            }
                            Button {
                                exportBlankTemplate()
                            } label: {
                                Label("Export Blank Template (CSV)…", systemImage: "doc.badge.plus")
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                        }
                        .accessibilityLabel("Import/Export")

                        // New template
                        Button { showBuilder = true } label: { Image(systemName: "plus.circle.fill") }
                    }
                }
            }
            .onAppear(perform: refresh)
            .sheet(isPresented: $showBuilder, onDismiss: refresh) {
                NavigationStack { AssessmentBuilderView() }
            }
            // Import CSV
            .sheet(isPresented: $isShowingImportPicker) {
                CSVImportPicker { url in
                    isShowingImportPicker = false
                    guard let url else { return }
                    importFromCSV(url: url)
                }
            }
            // Export selection UI
            .sheet(isPresented: $isShowingExportPicker) {
                NavigationStack {
                    ExportSelectionView(
                        assessments: assessments,
                        selected: $exportSelection,
                        onCancel: { isShowingExportPicker = false },
                        onExport: {
                            // Capture IDs and dismiss the sheet, then perform export
                            let ids = Array(exportSelection)
                            isShowingExportPicker = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                performExport(for: ids)
                            }
                        }
                    )
                }
            }
            .alert("Import Error", isPresented: $isShowingErrorAlert, presenting: importErrorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
        }
        .task {
            await copySeedIfNeeded()
            refresh()
        }
    }

    private func refresh() {
        assessments = AssessmentStorage.loadAll()
    }

    private func deleteAssessments(at offsets: IndexSet) {
        let items = offsets.map { assessments[$0] }
        for def in items {
            let fileName = AssessmentStorage.sanitized(def.title) + ".json"
            let url = AssessmentStorage.assessmentsDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
        refresh()
    }
}

extension AssessmentsHubView {
    private func copySeedIfNeeded() async {
        let dir = AssessmentStorage.assessmentsDirectory()
        let seedName = "Security_Review.json"
        let target = dir.appendingPathComponent(seedName)
        guard !FileManager.default.fileExists(atPath: target.path) else { return }
        if let url = Bundle.main.url(forResource: "SecurityReview.seed", withExtension: "json") {
            if let data = try? Data(contentsOf: url) { try? data.write(to: target, options: .atomic) }
        }
    }

    private func importFromCSV(url: URL) {
        // Handle security-scoped URLs (e.g., iCloud Drive, Files app)
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess { url.stopAccessingSecurityScopedResource() }
        }

        var readError: NSError?
        var loadedData: Data?

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var innerError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { coordinatedURL in
            do {
                loadedData = try Data(contentsOf: coordinatedURL)
            } catch {
                innerError = error as NSError
            }
        }
        if readError == nil { readError = innerError }

        if let readError {
            importErrorMessage = readError.localizedDescription
            isShowingErrorAlert = true
            return
        }

        guard let data = loadedData else {
            importErrorMessage = "Failed to read file."
            isShowingErrorAlert = true
            return
        }

        do {
            let def = try CSVCodec.decode(data: data)
            try AssessmentStorage.save(def)
            refresh()
        } catch {
            importErrorMessage = (error as NSError).localizedDescription
            isShowingErrorAlert = true
        }
    }

    private func performExport(for ids: [UUID]) {
        let selectedDefs = assessments.filter { ids.contains($0.id) }
        guard selectedDefs.isEmpty == false else { return }

        // Write each to a temp CSV file
        var urls: [URL] = []
        for def in selectedDefs {
            let data = CSVCodec.encode(definition: def)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(AssessmentStorage.sanitized(def.title))
                .appendingPathExtension("csv")
            do {
                try data.write(to: url, options: .atomic)
                urls.append(url)
            } catch {
                // Optionally collect/handle write errors per file
            }
        }
        guard !urls.isEmpty else { return }

        // Present share after ensuring we're back on the main view (sheet dismissed)
        DispatchQueue.main.async {
            presentMultiShare(urls: urls)
        }
    }

    private func presentMultiShare(urls: [URL]) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController
        else { return }

        let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }

    // Export a blank template CSV using the new header-based format
    private func exportBlankTemplate() {
        let data = CSVCodec.blankTemplateCSV()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Blank_Assessment_Template")
            .appendingPathExtension("csv")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }

        // Share the single file
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                  let root = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController
            else { return }

            let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let pop = vc.popoverPresentationController {
                pop.sourceView = root.view
                pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
                pop.permittedArrowDirections = []
            }
            root.present(vc, animated: true)
        }
    }
}

// A selection list to choose which templates to export
private struct ExportSelectionView: View {
    let assessments: [AssessmentDefinition]
    @Binding var selected: Set<UUID>
    let onCancel: () -> Void
    let onExport: () -> Void

    var body: some View {
        List {
            ForEach(assessments) { def in
                Button {
                    toggle(def.id)
                } label: {
                    HStack {
                        Image(systemName: selected.contains(def.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected.contains(def.id) ? .blue : .secondary)
                        Text(def.title)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Select Templates")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Export") { onExport() }
                    .disabled(selected.isEmpty)
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        // Prefer the key window if available
        return windows.first(where: { $0.isKeyWindow }) ?? windows.first
    }
}

