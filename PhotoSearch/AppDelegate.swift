//
//  AppDelegate.swift
//  PhotoSearch
//
//  Created by Nadim Alam on 16/01/2019.
//  Copyright © 2019 Nadim Alam. All rights reserved.
//

import UIKit

let themeColor = UIColor(red: 149/255, green: 44/255, blue: 146/255, alpha: 1.0)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        window?.tintColor = themeColor
        UINavigationBar.appearance().barTintColor = themeColor
        return true
    }
}

