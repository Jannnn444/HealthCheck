//
//  HealthKitManager.swift
//  SendBloodPressure
//
//  Created by Hualiteq International on 2025/7/22.
//

import SwiftUI
import HealthKit

// MARK: - HealthKit Manager (Alternative approach)
class HealthKitManager: ObservableObject, MCPServerProtocol {
    
    var tools: [Tool] = [
    Tool(name: "blood_pressure",
         toolDescription: "Get the latest blood pressure from apple health",
         input_schema: ["type": "object"])
    ]
    
    private let systolicType = HKQuantityType(.bloodPressureSystolic)
    private let diastolicType = HKQuantityType(.bloodPressureDiastolic)
    private let bloodPressureType = HKCorrelationType(.bloodPressure)
    
    func call(_ tool: Tool) async throws -> String {
        guard tool.name == "blood_pressure" else {
            
            throw NetworkError.toolNotSupported
        }
        let (systolic, diastolic) = try await fetchLastestBloodPressure()
        return "\(Int(systolic))/\(Int(diastolic))"
        
    }
    
    private let healthStore = HKHealthStore()
    
    @Published var isLoading = false
    @Published var isAuthorized = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            return
        }
        
        // Only check authorization for individual sample types, not the correlation type
        let typesToWrite: Set<HKSampleType> = [systolicType, diastolicType]
        
        let allAuthorized = typesToWrite.allSatisfy { type in
            healthStore.authorizationStatus(for: type) == .sharingAuthorized
        }
        
        DispatchQueue.main.async {
            self.isAuthorized = allAuthorized
        }
    }
    
    func requestHealthKitAuthorization(completion: @escaping (Bool, String) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, "HealthKit is not available on this device")
            return
        }
        
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            completion(false, "Failed to create HealthKit types")
            return
        }
        
        // Only request authorization for individual sample types, not the correlation type
        let typesToWrite: Set<HKSampleType> = [systolicType, diastolicType]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: nil) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.checkAuthorizationStatus()
                    completion(self.isAuthorized, self.isAuthorized ? "Authorization granted" : "Authorization denied")
                } else {
                    completion(false, "Authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func fetchLastestBloodPressure() async throws -> (systolic: Double, diastolic: Double) {
        
        let descriptor = HKSampleQueryDescriptor(predicates: [.sample(type: bloodPressureType)], sortDescriptors: [])
       
        let samples = try await descriptor.result(for: healthStore)
        guard let sample = samples.first as? HKCorrelation else {
            throw NetworkError.missingBloodPressureData
        }
        guard let systolic = sample.objects(for: systolicType).first as? HKQuantitySample, let diastolic = sample.objects(for: diastolicType).first as? HKQuantitySample else {
            throw NetworkError.missingBloodPressureData
        }
        let systolicValue = systolic.quantity.doubleValue(for: .millimeterOfMercury())
        let diastolicValue = diastolic.quantity.doubleValue(for: .millimeterOfMercury())
          return (systolicValue, diastolicValue)
    }
    
    func saveBloodPressureIntoHealthStore(systolic: Double, diastolic: Double, completion: @escaping (Bool, String) -> Void) {
        guard isAuthorized else {
            completion(false, "HealthKit authorization required")
            return
        }
        
        let bloodPressureUnit = HKUnit.millimeterOfMercury()
        
        let systolicQuantity = HKQuantity(unit: bloodPressureUnit, doubleValue: systolic)
        let diastolicQuantity = HKQuantity(unit: bloodPressureUnit, doubleValue: diastolic)
        
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic),
              let bloodPressureType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
            completion(false, "Failed to create HealthKit types")
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
        
        isLoading = true
        healthStore.save(bloodPressureCorrelation) { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    completion(true, "Blood Pressure values have been saved to Health App")
                } else {
                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                    completion(false, "An error occurred saving the blood pressure sample: \(errorMessage)")
                }
            }
        }
    }
}
