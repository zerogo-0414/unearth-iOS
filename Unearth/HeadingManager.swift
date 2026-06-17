//
//  HeadingManager.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import Foundation
import CoreLocation
import Combine

// MARK: - 朝向管理器
class HeadingManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = HeadingManager()

    private let locationManager = CLLocationManager()
    @Published var heading: Double = 0  // 0-360度，0为正北

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.headingFilter = 1  // 每1度更新一次
    }

    func startUpdatingHeading() {
        locationManager.startUpdatingHeading()
    }

    func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            // magneticHeading 是磁北方向
            self.heading = newHeading.magneticHeading
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }
}
