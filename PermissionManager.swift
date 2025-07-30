//
//  PermissionManager.swift
//  SendBloodPressure
//
//  Created by Hualiteq International on 2025/7/30.
//

import SwiftUI
import CoreLocation
import CoreBluetooth

// MARK: - Permission Manager
class PermissionManager: NSObject, ObservableObject {
    @Published var locationPermissionGranted = false
    @Published var bluetoothPermissionGranted = false
    @Published var showingPermissionView = false
    
    private let locationManager = CLLocationManager()
    private var bluetoothManager: CBCentralManager?
    
    override init() {
        super.init()
        locationManager.delegate = self
        checkInitialPermissions()
    }
    
    private func checkInitialPermissions() {
        // Check if this is first launch
        let hasShownPermissions = UserDefaults.standard.bool(forKey: "hasShownPermissions")
        
        if !hasShownPermissions {
            showingPermissionView = true
        } else {
            checkCurrentPermissions()
        }
    }
    
    private func checkCurrentPermissions() {
        // Check location permission
        locationPermissionGranted = locationManager.authorizationStatus == .authorizedWhenInUse ||
                                   locationManager.authorizationStatus == .authorizedAlways
        
        // Check Bluetooth permission (iOS 13+)
        if #available(iOS 13.0, *) {
            bluetoothManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestBluetoothPermission() {
        // Bluetooth permission is requested automatically when CBCentralManager is initialized
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func markPermissionsAsShown() {
        UserDefaults.standard.set(true, forKey: "hasShownPermissions")
        showingPermissionView = false
    }
}

// MARK: - Location Manager Delegate
extension PermissionManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.locationPermissionGranted = manager.authorizationStatus == .authorizedWhenInUse ||
                                           manager.authorizationStatus == .authorizedAlways
        }
    }
}

// MARK: - Bluetooth Manager Delegate
extension PermissionManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.bluetoothPermissionGranted = true
            case .unauthorized:
                self.bluetoothPermissionGranted = false
            default:
                break
            }
        }
    }
}

// MARK: - Permission Request View
struct PermissionRequestView: View {
    @ObservedObject var permissionManager: PermissionManager
    @State private var currentStep = 0
    
    private let permissions = [
        PermissionInfo(
            title: "Location Access",
            description: "We need location access to provide you with location-based features and services.",
            icon: "location.fill",
            color: .blue
        ),
        PermissionInfo(
            title: "Bluetooth Connection",
            description: "We need Bluetooth access to connect with nearby devices and provide enhanced functionality.",
            icon: "bluetooth",
            color: .cyan
        )
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 16) {
                Text("Welcome!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("To provide you with the best experience, we need a few permissions.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            
            // Permission Cards
            TabView(selection: $currentStep) {
                ForEach(0..<permissions.count, id: \.self) { index in
                    PermissionCard(
                        permission: permissions[index],
                        onAllow: {
                            handlePermissionRequest(for: index)
                        },
                        onSkip: {
                            nextStep()
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 400)
            
            Spacer()
            
            // Skip All Button
            Button("Skip All") {
                permissionManager.markPermissionsAsShown()
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 50)
        }
        .padding(.horizontal, 30)
        .background(Color(.systemBackground))
    }
    
    private func handlePermissionRequest(for step: Int) {
        switch step {
        case 0: // Location
            permissionManager.requestLocationPermission()
        case 1: // Bluetooth
            permissionManager.requestBluetoothPermission()
        default:
            break
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            nextStep()
        }
    }
    
    private func nextStep() {
        if currentStep < permissions.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            permissionManager.markPermissionsAsShown()
        }
    }
}

// MARK: - Permission Card
struct PermissionCard: View {
    let permission: PermissionInfo
    let onAllow: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: permission.icon)
                .font(.system(size: 60))
                .foregroundColor(permission.color)
            
            // Content
            VStack(spacing: 16) {
                Text(permission.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(permission.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onAllow) {
                    Text("Allow")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(permission.color)
                        .cornerRadius(12)
                }
                
                Button(action: onSkip) {
                    Text("Not Now")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(30)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

