import UserNotifications
import CoreLocation
import MessageUI
import KeyValueStore
import NudgeAnalytics
import nudgeBase
import os.log

private let fileName = "NudgeGeo.swift"

@objc open class NudgeGeo : NudgeBase {
    
    @objc public init(options: Dictionary<String,Any> = [:], callback: (()->Void)? = nil) {
        super.init()
        
        
        if (options["apiKey"] == nil) {
            return
        }

        // fetch server data for dynamic config
        KeyValueStore.registerObjects(defaults: [
            KeyValueStore.isNudgeEnabled: false,
            KeyValueStore.showLocationDialog: false,
            KeyValueStore.orgDesiredAccuracy: 2,
            KeyValueStore.orgDistanceFilter: 100.0,
            KeyValueStore.lastPermissionsPromptTime: 0.0,
            KeyValueStore.howManyTimesPrompted: 0,
            KeyValueStore.orgLocationDialogTitle: "Allow Location Access",
            KeyValueStore.orgLocationDialogBody: "Please allow location sharing to take full advantage of the following capabilities: \n\n   An important feature of this app is its ability to notify you with announcements whether you are at home or on the go, including important updates on lobby hours (or closings), near-by community events and possible fraud activity near you. \n\n   Your location information won't ever be shared with a third party, or be used for anything other than providing you with timely information, when and where you need it! \n\n   For now grant 'While Using' access, but when prompted later, please switch to 'Always Allow' for full functionality!",
            "location_permission": "Restricted or Denied"
        ])
        
        let apiKey = options["apiKey"] as! String
        let enabled = options["enabled"] != nil ? options["enabled"] as! Bool : false
        let federationId = options["federationId"] != nil ? (options["federationId"] as! String).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let showLocationDialog = options["showLocationDialog"] != nil ? options["showLocationDialog"] as! Bool : false
        
        self.checkIfEnabled(showLocationDialog: showLocationDialog, enabled: enabled, callback: callback)
        
        let userId = KeyValueStore.getString(key: KeyValueStore.userId)
        let deviceId = KeyValueStore.getString(key: KeyValueStore.deviceId)

        initializeNudge(apiKey: apiKey,
                             federationId: federationId,
                             userId: userId,
                             deviceId: deviceId,
                             success: {(newUserId, newDeviceId) in
                                self.initializeNudgeSuccess(newDeviceId: newDeviceId)},
                             failure: {(message) in
            NSLog("initializeNudge error:" + message)
        })
    }

    func checkIfEnabled(showLocationDialog: Bool, enabled: Bool, callback: (()->Void)? = nil) -> Void {
        // start NudgeGeo spcific

        KeyValueStore.putBoolean(key: KeyValueStore.showLocationDialog, value: showLocationDialog)
        // end NudgeGeo spcific
        if (!enabled){
            NudgeGeo.toggleEnabled(enabled: enabled, success: { res in }, failure: { (message) in NSLog(message)})
            KeyValueStore.putBoolean(key: KeyValueStore.isNudgeEnabled, value: enabled)
            // start NudgeGeo spcific
                let locMgr = LocationManagerDelegate.SharedManager
                if (callback != nil){
                    locMgr.locationCallback = callback
                }
                locMgr.stopMonitorinLocation()
            // end NudgeGeo spcific
            NSLog("nudge is disabled")
            return
        }
    }
    
    func initializeNudgeSuccess(newDeviceId: String, callback: (()->Void)? = nil) -> Void {
        print("=======================NUDGEGEO=======================")
     //   let deviceId = KeyValueStore.getString(key: KeyValueStore.deviceId)
        NudgeAnalytics.setupAnalytics()
        NudgeAnalytics.track(eventName: NudgeAnalytics.INTIALIZE_NUDGE, data: [:])
                            
        KeyValueStore.putBoolean(key: KeyValueStore.isNudgeEnabled, value: true)
                            
    //    let APNtoken = KeyValueStore.getString(key: KeyValueStore.APNtoken)
        let APNtoken = KeyValueStore.getString(key: KeyValueStore.APNtoken)
//        if #available(iOS 12.0, *) {
//            os_log(.debug, "=======================UserDefaults=======================")
//            os_log(.debug,  "%@", UserDefaults.standard.dictionaryRepresentation())
//        }
        if (APNtoken != nil) {
            print("APNtoken is \(String(describing: APNtoken))")
            NudgeGeo.registerToken(deviceId: newDeviceId, token: APNtoken, bundleId: NudgeBase.bundleId, success: {() in
                KeyValueStore.putString(key: KeyValueStore.APNtoken, value: APNtoken)
                DispatchQueue.main.async {
                    // start NudgeGeo spcific
                        let locMgr = LocationManagerDelegate.SharedManager
                        if (callback != nil){
                            locMgr.locationCallback = callback
                        }
                        locMgr.startMonitoringLocation()
                    // end NudgeGeo spcific
                    NSLog("You've been nudged!")
                
                }
            }, failure: {(message) in
                NSLog("registerToken error:" + message)
            })
        }
    }
    
    @objc public class func getLocationPermissionStatus() -> String {
        // Location Manager authoization status locked behind this switch mechanism and
        // has to be collected in this method
        switch CLLocationManager.authorizationStatus() {
                        case .authorizedAlways:
                            return "Always"
                        case .restricted, .denied, .authorizedWhenInUse:
                            return "Restricted or Denied"
                        case .notDetermined:
                            fallthrough
                        default:
                            return "Restricted or Denied"
                    }
    }
    
    @objc public class func setLocationPermissionDefault(){
        KeyValueStore.putString(key: KeyValueStore.locationPermission, value: getLocationPermissionStatus())
    }
    
}

