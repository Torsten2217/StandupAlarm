//
//  AppDelegate.m
//  StandupAlarm
//
//  Created by Apple Fan on 6/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "Reachability.h"
#import "CountingEngine.h"
#import "ExerciseViewController.h"

NSString *const SCSessionStateChangedNotification = @"standapp:SCSessionStateChangedNotification";

@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self checkDevice];
    
    NSArray* oldNotifications = [application scheduledLocalNotifications];
    
    for (UILocalNotification* notification in oldNotifications) {
        int notificationType = [[notification.userInfo objectForKey:kNotificationTypeKey] intValue];
        if (notificationType < 10)
            [application cancelLocalNotification:notification];
    }
    
    CountingEngine* engine = [CountingEngine getInstance];
#if USE_SPLASH
#if !USE_TEST_SPLASH
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [rootPath stringByAppendingPathComponent:@"firstlunch.inf"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
        [engine setFirstLunch: YES];
        NSArray* intervalArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:DEFAULT_INTERVAL], nil];
        [intervalArray writeToFile:plistPath atomically:YES];
    } else {
        [engine setFirstLunch: NO];
    }
#else
    [engine setFirstLunch:YES];
#endif
#else
    [engine setFirstLunch:NO];
#endif

    if (![engine firstLunch]) {
        UINavigationController *navc = (UINavigationController *)self.window.rootViewController;
        UIViewController *topvc = [navc topViewController];
        
        if ([topvc respondsToSelector:@selector(showMainMenuWithDelay)]) {
            [topvc performSelector:@selector(showMainMenuWithDelay)];
        }
    }

    self.localNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    UINavigationController *navc = (UINavigationController *)self.window.rootViewController;
    
    UIViewController *topvc = [navc topViewController];
    NSLog(@"applicationWillEnterForeground: %@", topvc);
    
    if ([topvc respondsToSelector:@selector(viewControllerWillEnterForeground)]) 
    {
        [topvc performSelector:@selector(viewControllerWillEnterForeground)];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    UINavigationController *navc = (UINavigationController *)self.window.rootViewController;
    
    UIViewController *topvc = [navc topViewController];
    
    if ([topvc respondsToSelector:@selector(viewControllerDidBecomeActive)]) 
    {
        [topvc performSelector:@selector(viewControllerDidBecomeActive)];
    }
}

- (void)application:application didReceiveLocalNotification:(UILocalNotification *)notification
{
    UINavigationController *navc = (UINavigationController *)self.window.rootViewController;

    int notificationType = [[notification.userInfo objectForKey:kNotificationTypeKey] intValue];

    if (notificationType == 10 && ![[navc topViewController] isKindOfClass:[ExerciseViewController class]]) {
        int alarmExercise = [[notification.userInfo objectForKey:kNotificationExerciseKey] intValue];
        if (alarmExercise == 0)
            [[CountingEngine getInstance] setCurrentActionRandomly];
        else
            [[CountingEngine getInstance] setCurrentActionAtIndex:alarmExercise % 1000 group:alarmExercise / 1000 - 1];
        
#ifdef FREEVERSION
        NSString* storyboardName = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"MainStoryboard_Free_iPad" : @"MainStoryboard_Free_iPhone";
#else
        NSString* storyboardName = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"MainStoryboard_iPad" : @"MainStoryboard_iPhone";
#endif
        if (isPhone568)
            storyboardName = [storyboardName stringByAppendingString:@"_568h"];
        
        UIStoryboard* storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
        
        ExerciseViewController* exerciseViewController = (ExerciseViewController*)[storyboard instantiateViewControllerWithIdentifier:@"exerciseViewController"];
        [exerciseViewController setScheduledExercise:YES];
        [navc pushViewController:exerciseViewController animated:YES];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // FBSample logic
    // if the app is going away, we close the session object; this is a good idea because
    // things may be hanging off the session, that need releasing (completion block, etc.) and
    // other components in the app may be awaiting close notification in order to do cleanup
    [FBSession.activeSession close];

    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSArray* oldNotifications = [application scheduledLocalNotifications];
    
    for (UILocalNotification* notification in oldNotifications) {
        int notificationType = [[notification.userInfo objectForKey:kNotificationTypeKey] intValue];
        if (notificationType < 10)
            [application cancelLocalNotification:notification];
    }
}

#pragma mark -

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    return [FBSession.activeSession handleOpenURL:url];
}

#pragma mark - Facebook related methods

- (void)sessionStateChanged:(FBSession *)session
                      state:(FBSessionState)state
                      error:(NSError *)error
{
    switch (state) {
        case FBSessionStateOpen:
            if (!error) {
                // We have a valid session
                NSLog(@"User session found");
            }

            [[NSNotificationCenter defaultCenter] postNotificationName:SCSessionStateChangedNotification
                                                                object:session];

            break;
        case FBSessionStateClosed:
        case FBSessionStateClosedLoginFailed:
            [FBSession.activeSession closeAndClearTokenInformation];
            break;
        default:
            break;
    }
    
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}

- (BOOL)openSessionWithAllowLoginUI:(BOOL)allowLoginUI {
    return [FBSession openActiveSessionWithPermissions:@[@"publish_stream"]
                                          allowLoginUI:allowLoginUI
                                     completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
                                         [self sessionStateChanged:session state:state error:error];
                                     }];
}

- (void)checkDevice
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
    {
        CGSize iOSDeviceScreenSize = [[UIScreen mainScreen] bounds].size;
        
/*
        if (iOSDeviceScreenSize.height == 480)
        {
            // Instantiate a new storyboard object using the storyboard file named Storyboard_iPhone35
            UIStoryboard *iPhone35Storyboard = [UIStoryboard storyboardWithName:@"Storyboard_iPhone35" bundle:nil];
            
            // Instantiate the initial view controller object from the storyboard
            UIViewController *initialViewController = [iPhone35Storyboard instantiateInitialViewController];
            
            // Instantiate a UIWindow object and initialize it with the screen size of the iOS device
            self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            
            // Set the initial view controller to be the root view controller of the window object
            self.window.rootViewController  = initialViewController;
            
            // Set the window object to be the key window and show it
            [self.window makeKeyAndVisible];
        }
*/
        
        if (iOSDeviceScreenSize.height == 568)
        {   // iPhone 5 and iPod Touch 5th generation: 4 inch screen
            // Instantiate a new storyboard object using the storyboard file named Storyboard_iPhone4
#ifdef FREEVERSION
            UIStoryboard *iPhone4Storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_Free_iPhone_568h" bundle:nil];
#else
            UIStoryboard *iPhone4Storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone_568h" bundle:nil];
#endif
            
            UIViewController *initialViewController = [iPhone4Storyboard instantiateInitialViewController];
            NSLog(@"%@", initialViewController);
            self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            self.window.rootViewController  = initialViewController;
//            [self.window makeKeyAndVisible];
        }
    }
}

@end
