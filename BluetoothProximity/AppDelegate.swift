//
//  AppDelegate.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/2/20.
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UITabBarControllerDelegate {

    var window: UIWindow?
    
    // For tab transitions. See these links for the original code:
    // https://stackoverflow.com/questions/51482618/viewcontroller-slide-animation
    // https://github.com/mattneub/Programming-iOS-Book-Examples/blob/master/bk2ch06p300customAnimation3b/ch19p620customAnimation1/AppDelegate.swift
    var context : UIViewControllerContextTransitioning?
    var interacting = false
    var anim : UIViewImplicitlyAnimating?
    var prev : UIPreviewInteraction!
    
    // Objects
    var logger: Logger!
    var sensors: Sensors!
    var advertiser: BluetoothAdvertiser!
    var scanner: BluetoothScanner!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Tab controller for transitions
        let tbc = self.window!.rootViewController as! UITabBarController
        tbc.delegate = self
        let prev = UIPreviewInteraction(view: tbc.tabBar)
        prev.delegate = self
        self.prev = prev
        
        // Objects
        logger = Logger()
        sensors = Sensors()
        advertiser = BluetoothAdvertiser()
        scanner = BluetoothScanner()
        
        return true
    }
    
    // Tab controller for transitions
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    // Tab controller for transitions
    func tabBarController(_ tabBarController: UITabBarController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return self.interacting ? self : nil
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
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
        self.logger.deleteLogs()
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "BluetoothProximity")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

// For tab transitions
extension AppDelegate : UIPreviewInteractionDelegate {
    func previewInteractionShouldBegin(_ previewInteraction: UIPreviewInteraction) -> Bool {
        let tbc = self.window!.rootViewController as! UITabBarController
        let loc = previewInteraction.location(in:tbc.tabBar)
        if loc.x > tbc.view!.bounds.midX {
            if tbc.selectedIndex < tbc.viewControllers!.count - 1 {
                self.interacting = true
                tbc.selectedIndex = tbc.selectedIndex + 1
                tbc.tabBar.isUserInteractionEnabled = false
                return true
            }
        } else {
            if tbc.selectedIndex > 0 {
                self.interacting = true
                tbc.selectedIndex = tbc.selectedIndex - 1
                tbc.tabBar.isUserInteractionEnabled = false
                return true
            }
        }
        return false
    }
    
    func previewInteraction(_ previewInteraction: UIPreviewInteraction, didUpdatePreviewTransition transitionProgress: CGFloat, ended: Bool) {
        var percent = transitionProgress
        if percent < 0.05 {percent = 0.05}
        if percent > 0.95 {percent = 0.95}
        self.anim?.fractionComplete = percent
        self.context?.updateInteractiveTransition(percent)
    }
    
    func previewInteraction(_ previewInteraction: UIPreviewInteraction, didUpdateCommitTransition transitionProgress: CGFloat, ended: Bool) {
        if ended {
            self.anim?.pauseAnimation()
            self.anim?.stopAnimation(false)
            self.anim?.finishAnimation(at: .end)
            let tbc = self.window!.rootViewController as! UITabBarController
            tbc.tabBar.isUserInteractionEnabled = true
        }
    }
    
    func previewInteractionDidCancel(_ previewInteraction: UIPreviewInteraction) {
        if let anim = self.anim as? UIViewPropertyAnimator {
            anim.pauseAnimation()
            anim.isReversed = true
            anim.continueAnimation(
                withTimingParameters:
                UICubicTimingParameters(animationCurve:.linear),
                durationFactor: 0.2)
            let tbc = self.window!.rootViewController as! UITabBarController
            tbc.tabBar.isUserInteractionEnabled = true
        }
    }

}

// For tab transitions
extension AppDelegate : UIViewControllerInteractiveTransitioning {
    
    func startInteractiveTransition(_ ctx: UIViewControllerContextTransitioning){
        self.context = ctx
        self.anim = self.interruptibleAnimator(using: ctx)
    }
    
}

// For tab transitions
extension AppDelegate : UIViewControllerAnimatedTransitioning {
    
    func interruptibleAnimator(using ctx: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        
        if self.anim != nil {
            return self.anim!
        }
        
        let vc1 = ctx.viewController(forKey:.from)!
        let vc2 = ctx.viewController(forKey:.to)!
        
        let con = ctx.containerView
        
        let r1start = ctx.initialFrame(for:vc1)
        let r2end = ctx.finalFrame(for:vc2)
        
        let v1 = ctx.view(forKey:.from)!
        let v2 = ctx.view(forKey:.to)!
        
        let tbc = self.window!.rootViewController as! UITabBarController
        let ix1 = tbc.viewControllers!.firstIndex(of:vc1)!
        let ix2 = tbc.viewControllers!.firstIndex(of:vc2)!
        let dir : CGFloat = ix1 < ix2 ? 1 : -1
        var r1end = r1start
        r1end.origin.x -= r1end.size.width * dir
        var r2start = r2end
        r2start.origin.x += r2start.size.width * dir
        v2.frame = r2start
        con.addSubview(v2)
        
        let anim = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
            v1.frame = r1end
            v2.frame = r2end
        }
        anim.addCompletion { finish in
            if finish == .end {
                ctx.finishInteractiveTransition()
                ctx.completeTransition(true)
            } else {
                ctx.cancelInteractiveTransition()
                ctx.completeTransition(false)
            }
        }
        
        self.anim = anim
        return anim
    }
    
    func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        
        let anim = self.interruptibleAnimator(using: ctx)
        anim.startAnimation()
        
    }
    
    func animationEnded(_ transitionCompleted: Bool) {
        self.interacting = false
        self.context = nil
        self.anim = nil
    }
    
}
