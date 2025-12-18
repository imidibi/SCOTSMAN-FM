//
//  AssessmentTemplateInterchange.swift
//  SalesDiver
//
//  Created by Assistant on 12/5/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - CSV Codec

enum CSVCodec {
    // Numeric mapping for field kinds
    // 1 = icon, 2 = number, 3 = text, 4 = yes/no, 5 = multipleChoice, 6 = date
    static func code(for kind: AssessmentFieldKind) -> Int {
        switch kind {
        case .icon: return 1
        case .number: return 2
        case .text: return 3
        case .yesno: return 4
        case .multipleChoice: return 5
        case .date: return 6
        }
    }

    static func kind(for code: Int) throws -> AssessmentFieldKind {
        switch code {
        case 1: return .icon
        case 2: return .number
        case 3: return .text
        case 4: return .yesno
        case 5: return .multipleChoice
        case 6: return .date
        default:
            throw CSVError.invalidKindCode
        }
    }

    enum CSVError: Error, LocalizedError {
        case invalidFormat
        case invalidKindCode
        case missingTemplateTitle
        case missingSectionTitle
        case missingFieldTitle
        case unexpectedRowType(line: Int, token: String)
        case missingHeader
        case headerMismatch

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Invalid CSV format."
            case .invalidKindCode: return "Unknown field type code."
            case .missingTemplateTitle: return "Missing template title."
            case .missingSectionTitle: return "Missing section title."
            case .missingFieldTitle: return "Missing field title."
            case let .unexpectedRowType(line, token):
                return "Unexpected row type at line \(line): '\(token)'. Expected Template, Section, or Field."
            case .missingHeader:
                return "Missing header row."
            case .headerMismatch:
                return "CSV header does not match expected columns."
            }
        }
    }

    // MARK: - New header-based format

    // Expected header columns (case-insensitive match)
    private static let headerColumns = [
        "RowType",
        "TemplateTitle",
        "SectionTitle",
        "FieldTitle",
        "KindCode",
        "IconSystemName",
        "Options",
        "DateISO8601"
    ]

    // Encoding a single template to CSV (new format)
    static func encode(definition: AssessmentDefinition) -> Data {
        var rows: [[String]] = []

        // Header row only, no instructional comments
        rows.append(headerColumns)

        // Template row
        rows.append([
            "Template",
            definition.title,
            "", // SectionTitle
            "", // FieldTitle
            "", // KindCode
            "", // IconSystemName
            "", // Options
            ""  // DateISO8601
        ])

        // For each section and field
        for section in definition.sections {
            // Section row
            rows.append([
                "Section",
                "",              // TemplateTitle (unused here)
                section.title,   // SectionTitle
                "",              // FieldTitle
                "",              // KindCode
                "",              // IconSystemName
                "",              // Options
                ""               // DateISO8601
            ])

            for field in section.fields {
                let kindCode = code(for: field.kind)
                let iconName = field.iconSystemName ?? ""
                let optionsString = field.options.map { $0.title }.joined(separator: "|")
                let dateString: String
                if let d = field.dateValue {
                    dateString = ISO8601DateFormatter().string(from: d)
                } else {
                    dateString = ""
                }

                rows.append([
                    "Field",
                    "",                 // TemplateTitle (unused here)
                    section.title,      // SectionTitle (explicit to ease editing)
                    field.title,        // FieldTitle
                    String(kindCode),   // KindCode
                    iconName,           // IconSystemName
                    optionsString,      // Options
                    dateString          // DateISO8601
                ])
            }
        }

        let csv = makeCSV(from: rows)
        return Data(csv.utf8)
    }

    // Decoding a single template from CSV
    static func decode(data: Data) throws -> AssessmentDefinition {
        guard var text = String(data: data, encoding: .utf8) else {
            throw CSVError.invalidFormat
        }

        // Strip UTF-8 BOM if present
        if text.hasPrefix("\u{feff}") {
            text.removeFirst()
        }

        // Split preserving line order for diagnostics
        let rawLines = text.components(separatedBy: CharacterSet.newlines)

        // Try the new header-based format first. If it fails due to missing header,
        // fall back to the legacy format.
        if looksLikeHeaderBasedFormat(rawLines) {
            return try decodeHeaderBased(rawLines: rawLines)
        } else {
            // Legacy fallback
            return try decodeLegacy(rawLines: rawLines)
        }
    }

    private static func looksLikeHeaderBasedFormat(_ lines: [String]) -> Bool {
        // Find first non-empty, non-comment line
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") { continue }
            let cols = trimTrailingEmpties(parseCSVRow(trimmed))
            guard cols.count >= 1 else { continue }
            // Compare first row as header, case-insensitive
            if cols.count >= headerColumns.count {
                // Normalize header by case-insensitive compare
                for (i, expected) in headerColumns.enumerated() {
                    if i >= cols.count { return false }
                    if cols[i].caseInsensitiveCompare(expected) != .orderedSame {
                        return false
                    }
                }
                return true
            }
            return false
        }
        return false
    }

    private static func decodeHeaderBased(rawLines: [String]) throws -> AssessmentDefinition {
        var iterator = rawLines.makeIterator()
        var lineIndex = 0

        // Find header row
        var headerCols: [String]? = nil
        while let raw = iterator.next() {
            lineIndex += 1
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let cols = trimTrailingEmpties(parseCSVRow(trimmed))
            if cols.isEmpty { continue }
            headerCols = cols
            break
        }

        guard let header = headerCols else { throw CSVError.missingHeader }
        guard header.count >= headerColumns.count else { throw CSVError.headerMismatch }
        for (i, expected) in headerColumns.enumerated() {
            if header[i].caseInsensitiveCompare(expected) != .orderedSame {
                throw CSVError.headerMismatch
            }
        }

        var title: String?
        var sections: [AssessmentSectionDefinition] = []
        var currentSection: AssessmentSectionDefinition?

        func pushCurrentSectionIfNeeded() {
            if let s = currentSection {
                sections.append(s)
                currentSection = nil
            }
        }

        // Process data rows
        while let raw = iterator.next() {
            lineIndex += 1
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let cols = trimTrailingEmpties(parseCSVRow(trimmed))
            
            if cols.isEmpty { continue }

            var padded = cols
            if padded.count < headerColumns.count {
                padded += Array(repeating: "", count: headerColumns.count - padded.count)
            }

            let rowType = padded[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let templateTitle = padded[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let sectionTitle = padded[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let fieldTitle = padded[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let kindCodeString = padded[4].trimmingCharacters(in: .whitespacesAndNewlines)
            let iconSystemName = padded[5].trimmingCharacters(in: .whitespacesAndNewlines)
            let optionsString = padded[6].trimmingCharacters(in: .whitespacesAndNewlines)
            let dateString = padded[7].trimmingCharacters(in: .whitespacesAndNewlines)

            switch rowType.lowercased() {
            case "template":
                pushCurrentSectionIfNeeded()
                guard !templateTitle.isEmpty else { throw CSVError.missingTemplateTitle }
                title = templateTitle

            case "section":
                guard !sectionTitle.isEmpty else { throw CSVError.missingSectionTitle }
                pushCurrentSectionIfNeeded()
                currentSection = AssessmentSectionDefinition(title: sectionTitle, fields: [])

            case "field":
                guard !fieldTitle.isEmpty else { throw CSVError.missingFieldTitle }
                guard let code = Int(kindCodeString) else { throw CSVError.invalidKindCode }
                let kind = try kind(for: code)
                var field = AssessmentFieldDefinition(title: fieldTitle, kind: kind)
                if !iconSystemName.isEmpty { field.iconSystemName = iconSystemName }
                if kind == .multipleChoice, !optionsString.isEmpty {
                    let titles = optionsString.split(separator: "|").map { String($0) }
                    field.options = titles.map { AssessmentFieldOption(title: $0) }
                }
                if kind == .date, !dateString.isEmpty {
                    field.dateValue = ISO8601DateFormatter().date(from: dateString)
                }

                // If no currentSection, create from sectionTitle if provided, else default
                if currentSection == nil {
                    let secTitle = sectionTitle.isEmpty ? "Section 1" : sectionTitle
                    currentSection = AssessmentSectionDefinition(title: secTitle, fields: [])
                } else if !sectionTitle.isEmpty && currentSection?.title != sectionTitle {
                    // If explicit SectionTitle differs, close current and start a new one
                    pushCurrentSectionIfNeeded()
                    currentSection = AssessmentSectionDefinition(title: sectionTitle, fields: [])
                }
                currentSection?.fields.append(field)

            default:
                throw CSVError.unexpectedRowType(line: lineIndex, token: rowType)
            }
        }

        // Finalize last section
        if let s = currentSection { sections.append(s) }

        guard let finalTitle = title, !finalTitle.isEmpty else {
            throw CSVError.missingTemplateTitle
        }
        return AssessmentDefinition(title: finalTitle, sections: sections)
    }

    // Decoding legacy format (backward compatibility)
    private static func decodeLegacy(rawLines: [String]) throws -> AssessmentDefinition {
        var title: String?
        var sections: [AssessmentSectionDefinition] = []
        var currentSection: AssessmentSectionDefinition?
        var seenTemplateTitle = false

        func pushCurrentSectionIfNeeded() {
            if let s = currentSection {
                sections.append(s)
                currentSection = nil
            }
        }

        for (idx, rawLine) in rawLines.enumerated() {
            let lineNumber = idx + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") { continue } // ignore comments

            let cols = trimTrailingEmpties(parseCSVRow(trimmed))
            var padded = cols
            guard !cols.isEmpty else { continue }

            // Normalize first token
            let firstRaw = padded[0]
            let first = normalizeToken(firstRaw)

            if equalsToken(first, "TemplateTitle") || equalsToken(first, "Template Title") {
                // TemplateTitle,<Title>
                guard padded.count >= 2 else { throw CSVError.missingTemplateTitle }
                title = padded[1]
                seenTemplateTitle = true
                continue
            }

            if equalsToken(first, "Section") {
                // Section,<Section Title>
                guard padded.count >= 2 else { throw CSVError.missingSectionTitle }
                pushCurrentSectionIfNeeded()
                currentSection = AssessmentSectionDefinition(title: padded[1], fields: [])
                continue
            }

            if equalsToken(first, "Field") {
                // Field,<Field Title>,<KindCode>,<IconSystemName>,<OptionsPipeSeparated>,<DateISO8601>
                guard padded.count >= 3 else { throw CSVError.missingFieldTitle }
                let fieldTitle = padded[1]
                let codeString = padded[2].trimmingCharacters(in: .whitespacesAndNewlines)
                guard let code = Int(codeString) else { throw CSVError.invalidKindCode }
                let kind = try kind(for: code)
                var field = AssessmentFieldDefinition(title: fieldTitle, kind: kind)

                if padded.count >= 4 {
                    let iconCol = padded[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !iconCol.isEmpty {
                        field.iconSystemName = iconCol
                    }
                }
                if padded.count >= 5, kind == .multipleChoice {
                    let optionsCol = padded[4].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !optionsCol.isEmpty {
                        let titles = optionsCol.split(separator: "|").map { String($0) }
                        field.options = titles.map { AssessmentFieldOption(title: $0) }
                    }
                }
                if padded.count >= 6, kind == .date {
                    let dateCol = padded[5].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !dateCol.isEmpty {
                        field.dateValue = ISO8601DateFormatter().date(from: dateCol)
                    }
                }

                if currentSection == nil {
                    currentSection = AssessmentSectionDefinition(title: "Section 1", fields: [])
                }
                currentSection?.fields.append(field)
                continue
            }

            // If we get here, it’s an unknown row type
            throw CSVError.unexpectedRowType(line: lineNumber, token: firstRaw)
        }

        // Finalize last section
        pushCurrentSectionIfNeeded()

        guard seenTemplateTitle, let finalTitle = title else {
            throw CSVError.missingTemplateTitle
        }

        return AssessmentDefinition(title: finalTitle, sections: sections)
    }

    // Blank template CSV in new header format with explicit field types
    static func blankTemplateCSV() -> Data {
        var rows: [[String]] = []
        rows.append(headerColumns)
        rows.append(["Template", "New Assessment", "", "", "", "", "", ""])
        rows.append(["Section", "", "Section 1", "", "", "", "", ""])
        // Six field kinds with clear examples
        rows.append(["Field", "", "Section 1", "Icon Example", "1", "lock.fill", "", ""])
        rows.append(["Field", "", "Section 1", "Text Example", "3", "", "", ""])
        rows.append(["Field", "", "Section 1", "Number Example", "2", "", "", ""])
        rows.append(["Field", "", "Section 1", "Yes/No Example", "4", "", "", ""])
        rows.append(["Field", "", "Section 1", "Multiple Choice Example", "5", "", "Basic|Standard|Premium", ""])
        rows.append(["Field", "", "Section 1", "Date Example", "6", "", "", "2025-12-05T00:00:00Z"])
        let csv = makeCSV(from: rows)
        return Data(csv.utf8)
    }

    // MARK: - CSV helpers (simple, with quoting)
    private static func makeCSV(from rows: [[String]]) -> String {
        rows.map { row in
            row.map { csvEscape($0) }.joined(separator: ",")
        }.joined(separator: "\n") + "\n"
    }

    private static func csvEscape(_ field: String) -> String {
        // Escape if contains quote, comma, newline, or leading/trailing space
        var needsQuotes = false
        if field.contains(",") || field.contains("\n") || field.contains("\r") || field.contains("\"") || field.hasPrefix(" ") || field.hasSuffix(" ") || field.hasPrefix("#") {
            needsQuotes = true
        }
        var value = field.replacingOccurrences(of: "\"", with: "\"\"")
        if needsQuotes {
            value = "\"\(value)\""
        }
        return value
    }

    private static func parseCSVRow(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        current.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    result.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }
            i += 1
        }
        result.append(current)
        return result
    }

    // Trim trailing empty columns
    private static func trimTrailingEmpties(_ cols: [String]) -> [String] {
        var c = cols
        while let last = c.last, last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            c.removeLast()
        }
        return c
    }

    // Normalize token (legacy first column), trimming Unicode whitespaces and collapsing internal spaces
    private static func normalizeToken(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Replace non-breaking spaces and multiple spaces with a single space
        let replacedNBSP = trimmed.replacingOccurrences(of: "\u{00A0}", with: " ")
        let collapsed = replacedNBSP.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return collapsed
    }

    // Case-insensitive equality for tokens
    private static func equalsToken(_ a: String, _ b: String) -> Bool {
        return a.caseInsensitiveCompare(b) == .orderedSame
    }
}

// MARK: - Document pickers

struct CSVImportPicker: UIViewControllerRepresentable {
    typealias Completion = (URL?) -> Void
    let onPick: Completion

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.commaSeparatedText, .plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: Completion
        init(onPick: @escaping Completion) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}

struct CSVExportShareSheet: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension View {
    func presentCSVExport(_ url: URL) -> some View {
        self.sheet(isPresented: .constant(true)) {
            CSVExportShareSheet(fileURL: url)
        }
    }
}

