//
//  AppDelegate.swift
//  FriendlyChat
//
//  Created by 夏语诚 on 2017/6/20.
//  Copyright © 2017年 Banana Inc. All rights reserved.
//

import UIKit
import Firebase
import GoogleSignIn
import UserNotifications // UserNotifactions are only required for the FCM step

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GIDSignInDelegate {

    var window: UIWindow?
    
    @available(iOS 9.0, *)
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return self.application(app, open: url, sourceApplication: options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String, annotation: "")
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApplication, annotation: annotation)
    }

    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            print("Error \(error)")
            return
        }
        
        guard let authentication = user.authentication else { return }
        let credential = FIRGoogleAuthProvider.credential(withIDToken: authentication.idToken, accessToken: authentication.accessToken)
        FIRAuth.auth()?.signIn(with: credential) { (user, error) in
            if let error = error {
                print("Error \(error)")
                return
            }
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FIRApp.configure()
        GIDSignIn.sharedInstance().clientID = FIRApp.defaultApp()?.options.clientID
        GIDSignIn.sharedInstance().delegate = self
        
        ////////////////////////////////////////////////////////////////////////
        //                                                                    //
        //  CODE BELOW THIS POINT IS ONLY REQUIRED FOR THE OPTIONAL FCM STEP  //
        //                                                                    //
        ////////////////////////////////////////////////////////////////////////
        
        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        if #available(iOS 10.0, *) {
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions) {_,_ in }
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        showAlert(withUserInfo: userInfo)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        showAlert(withUserInfo: userInfo)
        completionHandler(UIBackgroundFetchResult.newData)
    }

    func showAlert(withUserInfo userInfo: [AnyHashable: Any]) {
        let apsKey = "aps"
        let gcmMessage = "alert"
        let gcmLabel = "google.c.a.c_l"
        
        if let aps = userInfo[apsKey] as? NSDictionary {
            if let message = aps[gcmMessage] as? String {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: userInfo[gcmLabel] as? String ?? "", message: message, preferredStyle: .alert)
                    let dismissAction = UIAlertAction(title: "Dismiss", style: .destructive, handler: nil)
                    alert.addAction(dismissAction)
                    self.window?.rootViewController?.presentedViewController?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        showAlert(withUserInfo: userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        showAlert(withUserInfo: userInfo)
        
        completionHandler()
    }
}



