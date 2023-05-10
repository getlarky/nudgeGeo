//
//  LocationDelegate.swift
//  FBSnapshotTestCase
//
//  Created by Evan Snyder on 9/20/18.
//

// Needs debugging

import Foundation
import CoreLocation
import nudgeBase
import UIKit
import EnvironmentUtils
import KeyValueStore
import NudgeAnalytics

private let fileName = "LocationManagerDelegate.swift"
class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private final var MAXIMUM_UNCERTAINTY_FOR_USE = 100.0
    public var locationCallback: (() -> Void)? = nil
    
    private final var desiredAccuracies = [
        kCLLocationAccuracyBestForNavigation,
        kCLLocationAccuracyBest,
        kCLLocationAccuracyKilometer,
        kCLLocationAccuracyThreeKilometers
    ]
    
    static let SharedManager = LocationManagerDelegate ()
    
    private override init () {
        super.init()
        self.locationManager.delegate = self

        self.locationManager.desiredAccuracy = desiredAccuracies[KeyValueStore.getInt(key: KeyValueStore.orgDesiredAccuracy)]

        self.locationManager.distanceFilter = KeyValueStore.getDouble(key: KeyValueStore.orgDistanceFilter)

        if #available(iOS 9.0, *) {
            self.locationManager.allowsBackgroundLocationUpdates = true
        } else {
            NudgeAnalytics.trackError(error: "iOS version less than 9.0, not supporting location monitoring.", file: fileName, function: "init")
        }
        self.locationManager.pausesLocationUpdatesAutomatically = false
//        print("------- Location Manager Delegate initialized ------------")
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        print("------- Location Manager didChangeAuthorization ------------")
        switch status {
            case .restricted, .denied, .authorizedWhenInUse:
                self.locationManager.stopMonitoringSignificantLocationChanges()
                self.locationManager.stopUpdatingLocation()
                NudgeAnalytics.track(eventName: NudgeAnalytics.LOCATION_PERMISSION, data: ["location_permission" : "Restricted or Denied"])
                NudgeGeo.setLocationPermissionDefault();
                if let callable = locationCallback {
                    callable()
                }
                break
                
            case .authorizedAlways:
                startMonitoringLocation()
                NudgeAnalytics.track(eventName: NudgeAnalytics.LOCATION_PERMISSION, data: ["location_permission" : "Always"])
                NudgeGeo.setLocationPermissionDefault();
                if let callable = locationCallback {
                    callable()
                }
                break
                
            case .notDetermined:
                break
            default:
                break
        }
    }
    
    public func startMonitoringLocation() {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        if (authorizationStatus == .restricted || authorizationStatus == .denied) {
            NudgeAnalytics.trackError(error: "Location permissions restricted, not monitoring location", file: fileName, function: "startMonitoringLocation")
            if (KeyValueStore.getInt(key: KeyValueStore.howManyTimesPrompted) == 3){
                return
            }
        }
        let timesPrompted = KeyValueStore.getInt(key: KeyValueStore.howManyTimesPrompted)
        if ((authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways) || (timesPrompted == 0)) {
            let time = NSDate().timeIntervalSince1970
            let secondsSinceLastPrompted = 2628000.0
            
            let lastPromptTime = KeyValueStore.getDouble(key: KeyValueStore.lastPermissionsPromptTime)
            if ((lastPromptTime < (time + secondsSinceLastPrompted)) && (timesPrompted < 3)){
                KeyValueStore.putDouble(key: KeyValueStore.lastPermissionsPromptTime, value: time)
                if (KeyValueStore.getBoolean(key: KeyValueStore.showLocationDialog) == true){
                    
                    if (authorizationStatus != .denied || (authorizationStatus == .authorizedAlways) && (timesPrompted == 0)){
                        
                        KeyValueStore.putInt(key: KeyValueStore.howManyTimesPrompted, value: (timesPrompted + 1))
                        
                        let alertController = UIAlertController(
                            title: KeyValueStore.getString(key: KeyValueStore.orgLocationDialogTitle),
                            message: KeyValueStore.getString(key: KeyValueStore.orgLocationDialogBody),
                            preferredStyle: .alert
                        )
                        let actionOK = UIAlertAction(title: "OK", style: .default) { (action:UIAlertAction) in
                            self.locationManager.requestAlwaysAuthorization()
                        }
                        
                            
                        alertController.addAction(actionOK)
                        alertController.present(animated: true, completion: nil)
                        return
                        
                    }
                } else {
                    self.locationManager.requestAlwaysAuthorization()
                    return
                }
            }
        }
        if (!CLLocationManager.locationServicesEnabled()) {
            NudgeAnalytics.trackError(error: "Location services not enabled/available, not monitoring location", file: fileName, function: "startMonitoringLocation")
            return
        }
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        print("------- Start Location Monitoring ------------")
    }
    
    public func stopMonitorinLocation(){
        self.locationManager.stopMonitoringSignificantLocationChanges()
        self.locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        print("------- Location Update ------------")
        let lastLocation = locations.last!
        let uncertainty = lastLocation.horizontalAccuracy
        var paramsDict = [String:Any]()
        if (uncertainty < MAXIMUM_UNCERTAINTY_FOR_USE) {
            let lat = lastLocation.coordinate.latitude
            let lng = lastLocation.coordinate.longitude
            KeyValueStore.putDouble(key: KeyValueStore.Location.latitude, value: lat)
            KeyValueStore.putDouble(key: KeyValueStore.Location.longitude, value: lng)
            paramsDict["latitude"] = lat
            paramsDict["longitude"] = lng
            paramsDict["speed"] = lastLocation.speed
            let formatter = DateFormatter()
            formatter.dateFormat = Constants.dateFormat
            paramsDict["date_time"] = formatter.string(from: Date())
            paramsDict["organization_id"] = KeyValueStore.getString(key: KeyValueStore.organizationId)
            paramsDict["device_id"] = KeyValueStore.getString(key: KeyValueStore.deviceId)
            paramsDict["user_id"] = KeyValueStore.getString(key: KeyValueStore.userId)
            paramsDict["device_platform"] = KeyValueStore.devicePlatform
            
          //  let url = Constants.Core.url + Constants.Core.Endpoints.actionsByLocationAndDatetime
            let url = EnvironmentUtils.getNudgeURL(service: EnvironmentUtils.Service.CORE.rawValue) + Constants.Core.Endpoints.actionsByLocationAndDatetime
            print("actionsByLocationAndDatetime url is " + url)
            print("actionsByLocationAndDatetime postData is " + paramsDict.description)
            
            HttpClientApi.instance().makeAPICall(url: url, params:paramsDict, method: .POST, success: { (data, response, error) in
            }, failure: { (data, response, error) in
                NudgeAnalytics.trackError(error: response.debugDescription, file: fileName, function: "locationManager.didUpdateLocations")
            })
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NudgeAnalytics.trackError(error: error.localizedDescription, file: fileName, function: "locationManager.didFailWithError")
        if let error = error as? CLError, error.code == .denied {
            manager.stopUpdatingLocation()
            manager.stopMonitoringSignificantLocationChanges()
            return
        }
    }
}


