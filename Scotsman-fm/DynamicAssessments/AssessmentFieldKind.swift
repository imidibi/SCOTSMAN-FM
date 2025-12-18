//
//  AssessmentFieldKind.swift
//  SalesDiver
//
//  Created by Ian Miller on 11/11/25.
//


// Dynamic assessment data models and storage
// Created inside SalesDiver/DynamicAssessments so Xcode target can include it

import Foundation
import SwiftUI

enum AssessmentFieldKind: String, Codable, CaseIterable, Identifiable {
    case icon
    case number
    case text
    case yesno
    case multipleChoice
    case date
    
    var id: String { rawValue }
}

struct AssessmentFieldOption: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
}

struct AssessmentFieldDefinition: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var kind: AssessmentFieldKind
    // Icon options
    var iconSystemName: String? = nil
    var iconFileName: String? = nil
    // Multiple choice options
    var options: [AssessmentFieldOption] = []
    // Date field value (for default/template purposes)
    var dateValue: Date? = nil
}

struct AssessmentSectionDefinition: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var fields: [AssessmentFieldDefinition]
}

struct AssessmentDefinition: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var sections: [AssessmentSectionDefinition]
}

// MARK: - Storage for definitions
enum AssessmentStorage {
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func assessmentsDirectory() -> URL {
        let dir = documentsDirectory().appendingPathComponent("Assessments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    static func save(_ definition: AssessmentDefinition) throws {
        let url = assessmentsDirectory().appendingPathComponent("\(sanitized(definition.title)).json")
        let data = try JSONEncoder().encode(definition)
        try data.write(to: url, options: .atomic)
    }
    
    static func loadAll() -> [AssessmentDefinition] {
        let dir = assessmentsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var definitions: [AssessmentDefinition] = []
        for file in files where file.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: file), let def = try? JSONDecoder().decode(AssessmentDefinition.self, from: data) {
                definitions.append(def)
            }
        }
        return definitions
    }

    /// Attempts to load a single assessment by matching its UUID.
    /// Since definitions are stored one-per-file without the UUID in the filename,
    /// we scan all files and decode until we find a match.
    static func load(byID id: UUID) -> AssessmentDefinition? {
        let dir = assessmentsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return nil }
        for file in files where file.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: file), let def = try? JSONDecoder().decode(AssessmentDefinition.self, from: data) {
                if def.id == id { return def }
            }
        }
        return nil
    }

    /// Loads a definition by its sanitized title (direct filename match).
    /// Use this if you know the exact title used when the definition was saved.
    static func load(bySanitizedTitle sanitizedTitle: String) -> AssessmentDefinition? {
        let fileName = sanitizedTitle + ".json"
        let url = assessmentsDirectory().appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AssessmentDefinition.self, from: data)
    }
    
    static func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalid).joined().replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - Responses
struct AssessmentResponseFieldValue: Codable, Hashable {
    var text: String? = nil
    var number: Double? = nil
    var yesNo: Bool? = nil
    var date: Date? = nil
    var choiceID: UUID? = nil
    var choiceSelections: [UUID: Bool]? = nil
}

struct AssessmentResponse: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var assessmentID: UUID
    var assessmentTitle: String
    var companyID: String? = nil
    var createdAt: Date = Date()
    var values: [UUID: AssessmentResponseFieldValue]
}

enum AssessmentResponseStorage {
    static func responsesDirectory() -> URL {
        let dir = AssessmentStorage.assessmentsDirectory().appendingPathComponent("Responses", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    static func save(_ response: AssessmentResponse, for definition: AssessmentDefinition) throws {
        let base = AssessmentStorage.sanitized(definition.title)
        let fileName = "\(base)_\(ISO8601DateFormatter().string(from: response.createdAt)).json"
        let url = responsesDirectory().appendingPathComponent(fileName)
        let data = try JSONEncoder().encode(response)
        try data.write(to: url, options: .atomic)
    }
    
    static func loadLatest(for definition: AssessmentDefinition) -> AssessmentResponse? {
        let base = AssessmentStorage.sanitized(definition.title)
        let dir = responsesDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return nil }
        let matching = files.filter { $0.lastPathComponent.hasPrefix(base + "_") && $0.pathExtension.lowercased() == "json" }
        let sorted = matching.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let latest = sorted.last, let data = try? Data(contentsOf: latest) else { return nil }
        return try? JSONDecoder().decode(AssessmentResponse.self, from: data)
    }
    
    static func loadAll(forCompanyID companyID: String) -> [AssessmentResponse] {
        let dir = responsesDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var results: [AssessmentResponse] = []
        for file in files where file.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: file), let resp = try? JSONDecoder().decode(AssessmentResponse.self, from: data) {
                if resp.companyID == companyID {
                    results.append(resp)
                }
            }
        }
        // Sort newest first
        return results.sorted { $0.createdAt > $1.createdAt }
    }
}
