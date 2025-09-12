//
//  ContentViewModel.swift
//  SendBloodPressure
//
//  Created by Hualiteq International on 2025/9/12.
//
import SwiftUI
import Observation
 
@Observable
final class ContentViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
 
    private let mcpServerService: MCPServerProtocol
    private let anthropicService: AnthropicService
 
    init() {
        self.mcpServerService = HealthKitManager()
        self.anthropicService = AnthropicService(
            apiKey: "YOUR_API_KEY",
            tools: mcpServerService.tools
        )
    }
    
    func sendMessage() {
        let requestMessage = Request.Message(role: .user, content: [.text(text: inputText)])
        messages.append(.init(message: requestMessage))
        inputText = ""
        isLoading = true
     
        let requestMessages = messages.map(\.message)
     
        Task {
            do {
                let response = try await anthropicService.send(messages: requestMessages)
                let message = ChatMessage(message: .init(role: .assistant, content: response.content))
                self.messages.append(message)
            } catch {
                print("Error: \(error)")
            }
            self.isLoading = false
        }
    }
}
