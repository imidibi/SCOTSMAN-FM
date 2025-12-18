import SwiftUI
import CoreData
import UIKit

struct DynamicAssessmentView: View {
    let definition: AssessmentDefinition
    let companyID: String?
    let existingResponse: AssessmentResponse?
    
    init(definition: AssessmentDefinition, companyID: String? = nil, existingResponse: AssessmentResponse? = nil) {
        self.definition = definition
        self.companyID = companyID
        self.existingResponse = existingResponse
    }
    
    @State private var textValues: [UUID: String] = [:]
    @State private var numberValues: [UUID: Double] = [:]
    @State private var yesNoValues: [UUID: Bool] = [:]
    @State private var choiceValues: [UUID: UUID] = [:]
    @State private var multiChoiceToggles: [UUID: [UUID: Bool]] = [:]
    @State private var dateValues: [UUID: Date] = [:]
    @State private var saveStatus: String = ""
    @AppStorage("myCompanyName") private var myCompanyName = ""
    
    private var resolvedCompanyName: String {
        guard let companyID, let url = URL(string: companyID) else { return "Client" }
        // Try to resolve via the first connected scene's persistent container
        // We assume CoreDataManager.shared is available as in other files
        let context = CoreDataManager.shared.persistentContainer.viewContext
        if let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
            if let company = try? context.existingObject(with: objectID) as? CompanyEntity {
                return (company.name ?? "Client").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "Client"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(definition.title)
                    .font(.largeTitle)
                    .bold()
                HStack(spacing: 12) {
                    Button("Load Last") { loadLatest() }
                    Button("Save") { saveResponse() }
                    if !saveStatus.isEmpty { Text(saveStatus).font(.footnote).foregroundColor(.secondary) }
                }
                ForEach(definition.sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.title2)
                            .bold()
                        ForEach(section.fields) { field in
                            fieldView(field)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                }
            }
            .padding()
        }
        .onAppear {
            if let existing = existingResponse {
                preload(from: existing)
            } else {
                loadLatest()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportAssessmentAsPDF()
                    } label: {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }
                    Button {
                        exportAssessmentAsRTF()
                    } label: {
                        Label("Export Word (RTF)", systemImage: "doc.text")
                    }
                    Button {
                        exportAssessmentAsCSV()
                    } label: {
                        Label("Export Excel (CSV)", systemImage: "tablecells")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
    
    @ViewBuilder
    private func fieldView(_ field: AssessmentFieldDefinition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if field.kind == .icon {
                    if let name = field.iconSystemName, !name.isEmpty {
                        Image(systemName: name)
                            .foregroundColor(.blue)
                    }
                }
                Text(field.title).font(.headline)
            }
            switch field.kind {
            case .icon:
                // Removed the Text("Icon field").foregroundColor(.secondary) line as requested
                EmptyView()
            case .text:
                TextField("Enter text", text: Binding(
                    get: { textValues[field.id] ?? "" },
                    set: { textValues[field.id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            case .number:
                TextField("0", value: Binding(
                    get: { numberValues[field.id] ?? 0 },
                    set: { numberValues[field.id] = $0 }
                ), format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            case .yesno:
                Toggle("", isOn: Binding(
                    get: { yesNoValues[field.id] ?? false },
                    set: { yesNoValues[field.id] = $0 }
                ))
                .labelsHidden()
            case .multipleChoice:
                let opts = field.options
                if opts.isEmpty {
                    Text("No options configured")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(opts) { opt in
                            HStack {
                                Text(opt.title)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { multiChoiceToggles[field.id]?[opt.id] ?? false },
                                    set: { newVal in
                                        var map = multiChoiceToggles[field.id] ?? [:]
                                        map[opt.id] = newVal
                                        multiChoiceToggles[field.id] = map
                                    }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                }
            case .date:
                // Seed state on first render so the picker reflects a stable value
                let initialDate = dateValues[field.id] ?? field.dateValue ?? Date()
                DatePicker("", selection: Binding(
                    get: { dateValues[field.id] ?? initialDate },
                    set: { dateValues[field.id] = $0 }
                ), displayedComponents: .date)
                .onAppear {
                    if dateValues[field.id] == nil {
                        dateValues[field.id] = initialDate
                    }
                }
                .labelsHidden()
            }
        }
    }
    
    private func saveResponse() {
        var values: [UUID: AssessmentResponseFieldValue] = [:]
        for section in definition.sections {
            for field in section.fields {
                var v = AssessmentResponseFieldValue()
                switch field.kind {
                case .text:
                    v.text = textValues[field.id]
                case .number:
                    v.number = numberValues[field.id]
                case .yesno:
                    v.yesNo = yesNoValues[field.id]
                case .multipleChoice:
                    v.choiceSelections = multiChoiceToggles[field.id]
                case .icon:
                    break
                case .date:
                    // Persist the currently displayed date even if the user didn't adjust the picker
                    v.date = dateValues[field.id] ?? field.dateValue ?? Date()
                }
                values[field.id] = v
            }
        }
        let response = AssessmentResponse(assessmentID: definition.id, assessmentTitle: definition.title, companyID: companyID, values: values)
        do {
            try AssessmentResponseStorage.save(response, for: definition)
            saveStatus = "Saved at \(Date().formatted(date: .numeric, time: .standard))"
        } catch {
            saveStatus = "Save failed: \(error.localizedDescription)"
        }
    }
    
    private func loadLatest() {
        guard let latest = AssessmentResponseStorage.loadLatest(for: definition) else {
            saveStatus = "No saved responses"
            return
        }
        for section in definition.sections {
            for field in section.fields {
                let v = latest.values[field.id]
                switch field.kind {
                case .text:
                    textValues[field.id] = v?.text ?? ""
                case .number:
                    numberValues[field.id] = v?.number ?? 0
                case .yesno:
                    yesNoValues[field.id] = v?.yesNo ?? false
                case .multipleChoice:
                    if let selections = v?.choiceSelections {
                        multiChoiceToggles[field.id] = selections
                    }
                case .icon:
                    break
                case .date:
                    // Initialize state with saved date or field default to avoid defaulting to today
                    if let d = v?.date {
                        dateValues[field.id] = d
                    } else if let defaultDate = field.dateValue {
                        dateValues[field.id] = defaultDate
                    }
                }
            }
        }
        saveStatus = "Loaded last saved"
    }
    
    private func preload(from response: AssessmentResponse) {
        for section in definition.sections {
            for field in section.fields {
                let v = response.values[field.id]
                switch field.kind {
                case .text:
                    textValues[field.id] = v?.text ?? ""
                case .number:
                    numberValues[field.id] = v?.number ?? 0
                case .yesno:
                    yesNoValues[field.id] = v?.yesNo ?? false
                case .multipleChoice:
                    if let selections = v?.choiceSelections {
                        multiChoiceToggles[field.id] = selections
                    }
                case .icon:
                    break
                case .date:
                    // Initialize state with saved date or field default to avoid defaulting to today
                    if let d = v?.date {
                        dateValues[field.id] = d
                    } else if let defaultDate = field.dateValue {
                        dateValues[field.id] = defaultDate
                    }
                }
            }
        }
        saveStatus = "Loaded saved assessment"
    }
    
    private func presentShareSheet(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }

    private func exportAssessmentAsRTF() {
        let client = resolvedCompanyName
        let title = "IT Assessment for \(client)"
        let subtitle = "Performed by \(myCompanyName)\nAssessment Date: \(Date().formatted(date: .abbreviated, time: .omitted))"

        let attr = NSMutableAttributedString()
        let h1 = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 22)]
        let h2 = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)]
        let hSection = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18)]
        let body = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]

        attr.append(NSAttributedString(string: title + "\n", attributes: h1))
        attr.append(NSAttributedString(string: subtitle + "\n\n\n", attributes: h2))
        attr.append(NSAttributedString(string: definition.title + "\n\n", attributes: hSection))

        for section in definition.sections {
            attr.append(NSAttributedString(string: section.title + "\n", attributes: hSection))
            for field in section.fields {
                let name = field.title
                let value = renderedValue(for: field)
                attr.append(NSAttributedString(string: "• \(name): \(value)\n", attributes: body))
            }
            attr.append(NSAttributedString(string: "\n", attributes: body))
        }

        if let rtf = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            let safeClient = client.replacingOccurrences(of: " ", with: "_")
            let fileName = "\(safeClient)-\(definition.title.replacingOccurrences(of: " ", with: "_"))_Assessment.rtf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try rtf.write(to: tempURL)
                presentShareSheet(url: tempURL)
            } catch { }
        }
    }

    private func exportAssessmentAsCSV() {
        let client = resolvedCompanyName
        var rows: [[String]] = []
        rows.append(["IT Assessment for \(client)"])
        rows.append(["\(definition.title)"])
        rows.append(["Performed by \(myCompanyName)"])
        rows.append(["Assessment Date: \(Date().formatted(date: .abbreviated, time: .omitted))"])
        rows.append([""])
        rows.append(["Section", "Field", "Value"])
        for section in definition.sections {
            for field in section.fields {
                rows.append([section.title, field.title, renderedValue(for: field)])
            }
        }
        func escape(_ s: String) -> String {
            if s.contains(",") || s.contains("\n") || s.contains("\"") {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            } else { return s }
        }
        let csv = rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n") + "\n"
        let safeClient = client.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safeClient)-\(definition.title.replacingOccurrences(of: " ", with: "_"))_Assessment.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            presentShareSheet(url: url)
        } catch { }
    }

    private func exportAssessmentAsPDF() {
        let client = resolvedCompanyName
        let pageWidth = 612.0
        let pageHeight = 792.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let bodyFont = UIFont.systemFont(ofSize: 14)
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]

            let textWidth = pageWidth - 100

            let header = "IT Assessment for \(client)\n\(definition.title)\nPerformed by \(myCompanyName)\nAssessment Date: \(Date().formatted(date: .abbreviated, time: .omitted))\n" as NSString
            // Measure and draw header as a block, then add explicit padding below it
            let headerBounding = header.boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil)
            header.draw(with: CGRect(x: 50, y: 50, width: textWidth, height: headerBounding.height), options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil)
            // Start content below header with two extra blank lines worth of padding
            var y = 50 + headerBounding.height + 28
            let maxY = pageHeight - 50

            for section in definition.sections {
                // Prepare and measure the section title
                let sectionTitle = "\n\(section.title)\n" as NSString
                let sectionBounding = sectionTitle.boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil)
                // Page break if needed before drawing the title
                if y + sectionBounding.height > maxY {
                    context.beginPage()
                    y = 50
                }
                // Draw the title in a rect to respect line height
                sectionTitle.draw(with: CGRect(x: 50, y: y, width: textWidth, height: sectionBounding.height), options: .usesLineFragmentOrigin, attributes: titleAttrs, context: nil)
                y += sectionBounding.height // exactly one blank line already included in the string

                for field in section.fields {
                    let line = "• \(field.title): \(renderedValue(for: field))\n" as NSString
                    let bounding = line.boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: bodyAttrs, context: nil)
                    // Page break before drawing the line if needed
                    if y + bounding.height > maxY {
                        context.beginPage()
                        y = 50
                    }
                    line.draw(with: CGRect(x: 50, y: y, width: textWidth, height: bounding.height), options: .usesLineFragmentOrigin, attributes: bodyAttrs, context: nil)
                    y += bounding.height + 6
                }
            }
        }
        let safeClient = client.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safeClient)-\(definition.title.replacingOccurrences(of: " ", with: "_"))_Assessment.pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            presentShareSheet(url: tempURL)
        } catch { }
    }

    private func renderedValue(for field: AssessmentFieldDefinition) -> String {
        switch field.kind {
        case .text:
            return (textValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : (textValues[field.id] ?? "")
        case .number:
            if let n = numberValues[field.id] {
                if n.rounded(.towardZero) == n { // no fractional component
                    return String(Int(n))
                } else {
                    let formatter = NumberFormatter()
                    formatter.minimumFractionDigits = 0
                    formatter.maximumFractionDigits = 6
                    formatter.minimumIntegerDigits = 1
                    return formatter.string(from: NSNumber(value: n)) ?? String(n)
                }
            } else {
                return "—"
            }
        case .yesno:
            return (yesNoValues[field.id] ?? false) ? "Yes" : "No"
        case .multipleChoice:
            let map = multiChoiceToggles[field.id] ?? [:]
            if map.isEmpty { return "—" }
            // Join titles of selected options
            let selected = field.options.filter { map[$0.id] == true }.map { $0.title }
            return selected.isEmpty ? "—" : selected.joined(separator: ", ")
        case .icon:
            return ""
        case .date:
            let d = dateValues[field.id] ?? field.dateValue
            if let d { return DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .none) } else { return "—" }
        }
    }
}

