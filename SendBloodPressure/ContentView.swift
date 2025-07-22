//
//  ContentView.swift
//  SendBloodPressure
//
//  Created by Jan on 2025/7/22.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    var body: some View {
        VStack {
            BloodPressureView()
        }
        .padding()
    }
}

struct BloodPressureView: View {
    @State private var systolic: String = ""
    @State private var diastolic: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var isAuthorized = false
    @State private var authorizationRequested = false
    
    private let healthStore = HKHealthStore()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Blood Pressure Entry")
                .font(.title)
                .padding()
            
            // Authorization status
            HStack {
                Image(systemName: isAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(isAuthorized ? .green : .orange)
                Text(isAuthorized ? "HealthKit Authorized" : "HealthKit Authorization Required")
                    .font(.caption)
            }
            .padding(.horizontal)
            
            if !isAuthorized {
                Button("Request HealthKit Permission") {
                    requestHealthKitAuthorization()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Systolic (mmHg)")
                TextField("Enter systolic value", text: $systolic)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                
                Text("Diastolic (mmHg)")
                TextField("Enter diastolic value", text: $diastolic)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal)
            
            Button(action: {
                saveBloodPressure()
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Save to Health App")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isAuthorized ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(isLoading || systolic.isEmpty || diastolic.isEmpty || !isAuthorized)
            
            Spacer()
        }
        .alert("HealthDemo", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            checkAuthorizationStatus()
        }
    }
    
    private func checkAuthorizationStatus() {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            return
        }
        
        // Only check authorization for the individual sample types, not the correlation type
        let typesToWrite: Set<HKSampleType> = [systolicType, diastolicType]
        
        // Check if all required types are authorized
        let allAuthorized = typesToWrite.allSatisfy { type in
            healthStore.authorizationStatus(for: type) == .sharingAuthorized
        }
        
        isAuthorized = allAuthorized
        authorizationRequested = typesToWrite.contains { type in
            healthStore.authorizationStatus(for: type) != .notDetermined
        }
    }
    
    private func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            alertMessage = "HealthKit is not available on this device"
            showingAlert = true
            return
        }
        
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            alertMessage = "Failed to create HealthKit types"
            showingAlert = true
            return
        }
        
        // Only request authorization for individual sample types, not the correlation type
        let typesToWrite: Set<HKSampleType> = [systolicType, diastolicType]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: nil) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.checkAuthorizationStatus()
                    if self.isAuthorized {
                        self.alertMessage = "HealthKit access granted! You can now save blood pressure data."
                        self.showingAlert = true
                    }
                } else {
                    self.alertMessage = "HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func saveBloodPressure() {
        guard isAuthorized else {
            alertMessage = "Please authorize HealthKit access first"
            showingAlert = true
            return
        }
        
        guard let systolicValue = Double(systolic),
              let diastolicValue = Double(diastolic) else {
            alertMessage = "Please enter valid numeric values"
            showingAlert = true
            return
        }
        
        isLoading = true
        saveBloodPressureIntoHealthStore(systolic: systolicValue, diastolic: diastolicValue)
    }
    
    private func saveBloodPressureIntoHealthStore(systolic: Double, diastolic: Double) {
        let bloodPressureUnit = HKUnit.millimeterOfMercury()
        
        let systolicQuantity = HKQuantity(unit: bloodPressureUnit, doubleValue: systolic)
        let diastolicQuantity = HKQuantity(unit: bloodPressureUnit, doubleValue: diastolic)
        
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic),
              let bloodPressureType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.alertMessage = "Failed to create HealthKit types"
                self.showingAlert = true
            }
            return
        }
        
        let now = Date()
        
        let systolicSample = HKQuantitySample(type: systolicType,
                                            quantity: systolicQuantity,
                                            start: now,
                                            end: now)
        let diastolicSample = HKQuantitySample(type: diastolicType,
                                             quantity: diastolicQuantity,
                                             start: now,
                                             end: now)
        
        let objects: Set<HKSample> = [systolicSample, diastolicSample]
        let bloodPressureCorrelation = HKCorrelation(type: bloodPressureType,
                                                   start: now,
                                                   end: now,
                                                   objects: objects)
        
        healthStore.save(bloodPressureCorrelation) { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.alertMessage = "Blood Pressure values have been saved to Health App"
                    self.systolic = ""
                    self.diastolic = ""
                } else {
                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                    self.alertMessage = "An error occurred saving the blood pressure sample: \(errorMessage)"
                    print("Error saving blood pressure: \(errorMessage)")
                }
                
                self.showingAlert = true
            }
        }
    }
}


#Preview {
    ContentView()
}
