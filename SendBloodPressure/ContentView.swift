//
//  ContentView.swift
//  SendBloodPressure
//  Created by Hualiteq International on 2025/7/30.
//

import Foundation
import SwiftUI

// MARK: - Main App Integration
struct ContentView: View {
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some View {
        ZStack {
            // Your main app content
            MainAppView()
            
            // Permission overlay
            if permissionManager.showingPermissionView {
                PermissionRequestView(permissionManager: permissionManager)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: permissionManager.showingPermissionView)
    }
}



