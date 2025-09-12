//
//  AnthropicService.swift
//  SendBloodPressure
//
//  Created by Hualiteq International on 2025/9/12.
//

import Foundation
 
final class AnthropicService {
 
    private let apiKey: String
    private let tools: [Tool]
    
    init(apiKey: String, tools: [Tool]) {
        self.apiKey = apiKey
        self.tools = tools
    }
    
    func send(messages: [Request.Message]) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body = Request(model: "claude-3-opus-20240229", messages: messages, max_tokens: 1024, tools: tools)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // In your AnthropicService.send method, add this before decoding:
        print("Raw API Response: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
