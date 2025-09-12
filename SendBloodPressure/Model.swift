//
//  Model.swift
//  SendBloodPressure
//
//  Created by Hualiteq International on 2025/7/30.
//

import Foundation
import SwiftUI

struct PermissionInfo {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

protocol MCPServerProtocol {
    var tools: [Tool] { get }
    func call(_ tool: Tool) async throws -> String
}

struct Tool: Encodable {
    enum CodingKeys: String, CodingKey {
        case name, toolDescription = "description", input_schema
    }
    let name: String
    let toolDescription: String
    let input_schema: [String: String]
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingFailed
    case serverError(Int)
    case toolNotSupported
    case missingBloodPressureData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingFailed:
            return "Failed to decode data"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .toolNotSupported:
            return "Tool not supported"
        case .missingBloodPressureData:
            return "Missing blood pressure data"
        }
    }
}


struct Request: Encodable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let tools: [Tool]?
 
    struct Message: Encodable {
        enum Role: String, Encodable {
            case user
            case assistant
        }
        
        let role: Role
        let content: [Content]
    }
}

 
struct Response: Decodable {
    let content: [Content]
}

enum Content: Codable {
    case text(text: String)
    case toolUse(id: String, name: String, input: [String: String])
    case toolResult(toolUseId: String, content: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, tool_use_id, content
    }
    
    private enum ContentType: String, Codable {
        case text
        case tool_use
        case tool_result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        
        switch type {
        case .text:
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text: text)
            
        case .tool_use:
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decode([String: String].self, forKey: .input)
            self = .toolUse(id: id, name: name, input: input)
            
        case .tool_result:
            let toolUseId = try container.decode(String.self, forKey: .tool_use_id)
            let content = try container.decode(String.self, forKey: .content)
            self = .toolResult(toolUseId: toolUseId, content: content)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(text, forKey: .text)
            
        case .toolUse(let id, let name, let input):
            try container.encode(ContentType.tool_use, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
            
        case .toolResult(let toolUseId, let content):
            try container.encode(ContentType.tool_result, forKey: .type)
            try container.encode(toolUseId, forKey: .tool_use_id)
            try container.encode(content, forKey: .content)
        }
    }
}

struct ChatMessage: Identifiable {
 
    let message: Request.Message
 
    var id: UUID = .init()
 
    var content: String {
        message.content
            .map { content in
                switch content {
                case .text(let text):
                    text
                case .toolUse(_, let name, _):
                    "Called MCP Tool: \(name)"
                case .toolResult(_, let content):
                    "Result: \(content)"
                }
            }
            .joined(separator: "\n")
    }
}
