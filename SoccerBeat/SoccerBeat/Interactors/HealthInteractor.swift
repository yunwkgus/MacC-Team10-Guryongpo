//
//  HealthInteractor.swift
//  SoccerBeat
//
//  Created by daaan on 11/1/23.
//

import Foundation
import HealthKit

class HealthInteractor: ObservableObject {
    var healthStore = HKHealthStore()
    
    var allWorkouts: [HKWorkout] = []
    var allRoutes: [HKWorkoutRoute] = []
    
    static let shared = HealthInteractor()
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        let typeToRead = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!,
                              HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                              HKObjectType.quantityType(forIdentifier: .runningSpeed)!,
                              HKObjectType.quantityType(forIdentifier: .walkingSpeed)!,
                              HKSeriesType.workoutType(),
                              HKSeriesType.workoutRoute(),
                              HKObjectType.activitySummaryType(),
                             ])
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("requestAuthorization: health data not available")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typeToRead) { success, error in
            if success {
                Task {
                    await self.fetchAllData()
                }
            }
        }
    }
    
    func fetchAllData() async {
        print("fetchAllData: attempting to fetch all data..")
        
        allWorkouts = await getAllWorkout() ?? []
        allRoutes = await getWorkoutRoute(workout: allWorkouts[0]) ?? []
    }
    
    func getAllWorkout() async -> [HKWorkout]? {
        let soccer = HKQuery.predicateForWorkouts(with: .running)
        
        let data = try! await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            healthStore.execute(HKSampleQuery(sampleType: .workoutType(), predicate: soccer, limit: HKObjectQueryNoLimit,sortDescriptors: [.init(keyPath: \HKSample.startDate, ascending: false)], resultsHandler: { query, samples, error in
                if let hasError = error {
                    continuation.resume(throwing: hasError)
                    return
                }
                continuation.resume(returning: samples!)
            }))
        }
        guard let workouts = data as? [HKWorkout] else {
            return nil
        }
        return workouts
    }
    
    func getWorkoutRoute(workout: HKWorkout) async -> [HKWorkoutRoute]? {
        let byWorkout = HKQuery.predicateForObjects(from: workout)
        
        let data = try! await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            healthStore.execute(HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(), predicate: byWorkout, anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: { (query, samples, deletedObjects, anchor, error) in
                if let hasError = error {
                    continuation.resume(throwing: hasError)
                    return
                }
                continuation.resume(returning: samples!)
            }))
        }
        guard let workouts = data as? [HKWorkoutRoute] else {
            return nil
        }
        return workouts
    }
}