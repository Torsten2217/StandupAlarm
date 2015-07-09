//
//  CountingEngine.m
//  StandupAlarm
//
//  Created by Apple Fan on 6/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CountingEngine.h"
#import <QuartzCore/CAAnimation.h>
#import "ActionsGroup.h"
#import "Config.h"

@implementation CountingEngine

@synthesize targetInterval;
@synthesize nextTargetInterval;
@synthesize targetTime;
@synthesize pausedTime;

@synthesize adCounter;
@synthesize restartFlag;

@synthesize firstLunch;
@synthesize networkStatus;

NSString *kNotificationTypeKey      = @"kNotificationTypeKey";
NSString *kNotificationGuidKey      = @"kNotificationGuidKey";
NSString *kNotificationWeekdaysKey  = @"kNotificationWeekdaysKey";
NSString *kNotificationExerciseKey  = @"kNotificationExerciseKey";

static id __strong instance = nil;

+ (CountingEngine*)getInstance
{
    if (instance == nil) {
        instance = [[CountingEngine alloc] init];
    }

    return instance;
}

- (id)init
{
    self = [super init];

    NSString* cur_ver = [[NSUserDefaults standardUserDefaults] objectForKey:@"version"];
    NSString* app_ver = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

    // if update, remove old data
    if (cur_ver == nil || app_ver == nil || [cur_ver compare:app_ver options:NSNumericSearch] == NSOrderedAscending) {
        NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *plistPath = [rootPath stringByAppendingPathComponent:@"ActionList.plist"];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:plistPath])
            [fileManager removeItemAtPath:plistPath error:nil];
    }
    
    // save current version
    [[NSUserDefaults standardUserDefaults] setObject:app_ver forKey:@"version"];
    
    targetInterval = 5;
    nextTargetInterval = 5;
    targetTime = 0;
    pausedTime = 0;
    
    adCounter = 0;
    restartFlag = NO;
    
    firstLunch = YES;
    networkStatus = 0;
    
    srand(time(0));
    [self loadActionList];
    [self loadCaloriesData];

    return self;
}

- (void)startCounting
{
    [self startCountingWithInterval:nextTargetInterval scheduleType:0 resetInterval:YES];
}

- (void)startCountingWithInterval:(int) interval scheduleType:(int)scheduleType resetInterval:(bool)resetInterval
{
    targetInterval = interval;
    targetTime = GETCURRENTTIME + targetInterval + 1;
    pausedTime = 0;
    
    if (resetInterval) {
        nextTargetInterval = targetInterval;
        [self setCurrentActionRandomly];
    }

    [self scheduleAlarmForDate:[NSDate dateWithTimeIntervalSinceNow:targetInterval] scheduleType:scheduleType];
    
    NSDictionary *action = [self currentAction];
    [action setValue:[NSNumber numberWithBool:NO] forKey:@"actionQueue"];
    
    if ([self isEmeptyActionQueue]) {
        [self resetActionQueue];
        [action setValue:[NSNumber numberWithBool:NO] forKey:@"actionQueue"];
    }
    
    [[CountingEngine getInstance] saveActionList];
}

- (void)stopCounting
{
    targetTime = 0;
    pausedTime = 0;
    
    [self unscheduleAlarm];
}

- (void)pauseCounting
{
    pausedTime = GETCURRENTTIME;
    [self unscheduleAlarm];
}

- (void)resumeCounting
{
    [self scheduleAlarmForDate:[NSDate dateWithTimeIntervalSinceNow:(targetTime - pausedTime)] scheduleType:0];

    targetTime += (GETCURRENTTIME - pausedTime);
    pausedTime = 0;
}

- (bool)isPaused
{
    return pausedTime != 0;
}

- (bool)isReachedTarget
{
    return (targetTime > 0) && (pausedTime == 0) && (GETCURRENTTIME >= targetTime);
}

- (int)getRemainingTimeValue
{
    int remainingTime = 0;
    
    if (![self isReachedTarget]) {
        
        if (pausedTime == 0) {        // running state
            remainingTime = (targetTime - GETCURRENTTIME);
        } else {
            remainingTime = (targetTime - pausedTime);
        }
    }
    
    if (remainingTime < 0)
        remainingTime = 0;
    
    return remainingTime;
}
- (float)getPassRate
{
    return 1 - ((float)[self getRemainingTimeValue] / targetInterval);
}

- (NSString*)getRemainingTimeString
{
    int remainingTime = [self getRemainingTimeValue];
    return [NSString stringWithFormat:@"%02d:%02d", remainingTime / 60, remainingTime % 60];
}


- (void)scheduleAlarmForDate:(NSDate*)theDate scheduleType:(int)scheduleType
{
    [self unscheduleAlarm];

    UIApplication* app = [UIApplication sharedApplication];
    
    UILocalNotification* alarm = [[UILocalNotification alloc] init];
    if (alarm)
    {
        alarm.soundName = UILocalNotificationDefaultSoundName;
        alarm.timeZone = [NSTimeZone defaultTimeZone];

        if (scheduleType == 1) {            // exercise timer
            
            // schedule timer to get back to work
            alarm.alertBody = @"Get back to work :)";
            alarm.fireDate = theDate;
            alarm.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:kNotificationTypeKey];
            [app scheduleLocalNotification:alarm];
            
            // starting time to schedule continued exercise timer
            theDate = [theDate dateByAddingTimeInterval:nextTargetInterval];
            
        } else if (scheduleType == 2) {     // snooze timer
            
            // schedule snooze timer
            alarm.alertBody = @"Time for a standing break!";
            alarm.fireDate = theDate;
            alarm.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:2] forKey:kNotificationTypeKey];
            [app scheduleLocalNotification:alarm];
            
            // starting time to schedule continued exercise timer
            theDate = [theDate dateByAddingTimeInterval:nextTargetInterval];
            
        }

        // schedule exercise timer
        alarm.alertBody = @"Time for a standing break!";
        alarm.userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0] forKey:kNotificationTypeKey];

#if !USE_TEST_TIME
        switch (nextTargetInterval) {
            case 1 * 60:
                alarm.fireDate = theDate;
                alarm.repeatInterval = NSMinuteCalendarUnit;
                [app scheduleLocalNotification:alarm];
                
                break;
            case 2 * 60:
            case 3 * 60:
            case 4 * 60:
            case 5 * 60:
            case 6 * 60:
            case 10 * 60:
            case 12 * 60:
            case 15 * 60:
            case 20 * 60:
            case 30 * 60:
                // one hour has INTERVAL mins x N times
                for (int i = 0; i < 60 * 60 / nextTargetInterval; i++) {
                    alarm.fireDate = [NSDate dateWithTimeInterval:i * nextTargetInterval sinceDate:theDate];
                    alarm.repeatInterval = NSHourCalendarUnit;
                    [app scheduleLocalNotification:alarm];
                }
                
                break;
/*            case 15 * 60:
                // one hour has 15 mins x 4 times
                for (int i = 0; i < 4; i++) {
                    alarm.fireDate = [NSDate dateWithTimeInterval:i * 15 * 60 sinceDate:theDate];
                    alarm.repeatInterval = NSHourCalendarUnit;
                    [app scheduleLocalNotification:alarm];
                }
                
                break;
            case 30 * 60:
                alarm.fireDate = theDate;
                alarm.repeatInterval = NSHourCalendarUnit;                
                [app scheduleLocalNotification:alarm];

                alarm.fireDate = [NSDate dateWithTimeInterval: 30 * 60 sinceDate:theDate];
                alarm.repeatInterval = NSHourCalendarUnit;
                [app scheduleLocalNotification:alarm];

                break;*/
            case 45 * 60:
                // one day has 45 mins x 32 times
                for (int i = 0; i < 32; i++) {
                    alarm.fireDate = [NSDate dateWithTimeInterval:i * 45 * 60 sinceDate:theDate];
                    alarm.repeatInterval = NSDayCalendarUnit;
                    [app scheduleLocalNotification:alarm];
                }
                
                break;
            case 60 * 60:
                alarm.fireDate = theDate;
                alarm.repeatInterval = NSHourCalendarUnit;
                [app scheduleLocalNotification:alarm];

                break;
            case 90 * 60:
                // one day has 90 mins x 16 times
                for (int i = 0; i < 16; i++) {
                    alarm.fireDate = [NSDate dateWithTimeInterval:i * 90 * 60 sinceDate:theDate];
                    alarm.repeatInterval = NSDayCalendarUnit;
                    [app scheduleLocalNotification:alarm];
                }
                
                break;
            case 120 * 60:
                // one day has 90 mins x 12 times
                for (int i = 0; i < 12; i++) {
                    alarm.fireDate = [NSDate dateWithTimeInterval:i * 120 * 60 sinceDate:theDate];
                    alarm.repeatInterval = NSDayCalendarUnit;
                    [app scheduleLocalNotification:alarm];
                }
                
                break;
        }
#else
        int cnt = 60 / nextTargetInterval;
        for (int i = 0; i < cnt; i++) {
            alarm.fireDate = [NSDate dateWithTimeInterval:i * 60 / cnt sinceDate:theDate];
            alarm.repeatInterval = NSMinuteCalendarUnit;
            [app scheduleLocalNotification:alarm];
        }
#endif
    }
}

- (void)unscheduleAlarm
{
    UIApplication* app = [UIApplication sharedApplication];
    NSArray* oldNotifications = [app scheduledLocalNotifications];
    
    for (UILocalNotification* notification in oldNotifications) {
        int notificationType = [[notification.userInfo objectForKey:kNotificationTypeKey] intValue];
        if (notificationType < 10)
            [app cancelLocalNotification:notification];
    }
}

- (void)loadActionList
{
    NSString *errorDesc = nil;
    NSPropertyListFormat format;
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [rootPath stringByAppendingPathComponent:@"ActionList.plist"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath])
        plistPath = [[NSBundle mainBundle] pathForResource:@"ActionList" ofType:@"plist"];
    
    NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:plistPath];
    actionsGroupList = [NSPropertyListSerialization propertyListFromData:plistXML
                                                        mutabilityOption:NSPropertyListMutableContainers
                                                                  format:&format
                                                        errorDescription:&errorDesc];
    
    if (!actionsGroupList) {
        NSLog(@"Error reading plist: %@, format: %d", errorDesc, format);
    }
    
    BOOL flag = false;
    for (currentGroup = 0; currentGroup < [actionsGroupList count]; currentGroup++) {
        NSDictionary* group = [actionsGroupList objectAtIndex:currentGroup];
        NSArray* actionList = [group objectForKey:@"actionList"];
        for (currentIndex = 0; currentIndex < [actionList count]; currentIndex++) {
            if ([[[actionList objectAtIndex:currentIndex] objectForKey:@"actionEnabled"] boolValue]) {
                flag = true;
                break;
            }
        }
        
        if (flag)
            break;
    }
}

- (void)saveActionList
{
    NSString *error;
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [rootPath stringByAppendingPathComponent:@"ActionList.plist"];

    NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:actionsGroupList
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                         errorDescription:&error];
    if(plistData) {
        [plistData writeToFile:plistPath atomically:YES];
    } else {
        NSLog(@"%@", error);
    }
}

- (int)numberOfActionGroups
{
    return [actionsGroupList count];
}

- (NSString*)titleOfActionGroup:(int)group
{
    NSDictionary *actionGroup = [actionsGroupList objectAtIndex:group];
    return [actionGroup objectForKey:@"groupTitle"];
}

- (int)numberOfActionsForGroup:(int)group
{
    NSDictionary *actionGroup = [actionsGroupList objectAtIndex:group];
    NSArray *actionList = [actionGroup objectForKey:@"actionList"];
    return [actionList count];
}

- (NSDictionary*)actionAtIndex:(int)index group:(int)group
{
    NSDictionary *actionGroup = [actionsGroupList objectAtIndex:group];
    NSArray *actionList = [actionGroup objectForKey:@"actionList"];
    return [actionList objectAtIndex:index];
}

- (NSDictionary*)currentAction
{
    return [self actionAtIndex:currentIndex group:currentGroup];
}

- (void)setCurrentActionAtIndex:(int)index group:(int)group
{
    currentGroup = group;
    currentIndex = index;
}

- (void)setCurrentActionRandomly
{
    NSMutableArray* temp = [[NSMutableArray alloc] init];

    for (int i = 0; i < [actionsGroupList count]; i++) {
        NSDictionary* group = [actionsGroupList objectAtIndex:i];
        NSArray* actionList = [group objectForKey:@"actionList"];
        for (int j = 0; j < [actionList count]; j++) {
            NSDictionary* action = [actionList objectAtIndex:j];
            if ([[action objectForKey:@"actionEnabled"] boolValue] && [[action objectForKey:@"actionQueue"] boolValue]) {
                [temp addObject:[NSNumber numberWithInt:(i * 100 + j)]];
            }
        }
    }
    
    if ([temp count] > 0) {
        int k = rand() % [temp count];
//        int k = arc4random() % [temp count];
        int group_index = [[temp objectAtIndex:k] intValue];

        currentGroup = group_index / 100;
        currentIndex = group_index % 100;
    } else {
        currentGroup = 0;
        currentIndex = 0;
    }
}

- (void)setCurrentActionEnabled:(BOOL)enable
{
    NSDictionary* action = [self currentAction];
    [action setValue:[NSNumber numberWithBool:enable] forKey:@"actionEnabled"];
    
    [self saveActionList];
}

- (BOOL)isEmeptyActionQueue
{
    for (int i = 0; i < [actionsGroupList count]; i++) {
        NSDictionary* group = [actionsGroupList objectAtIndex:i];
        NSArray* actionList = [group objectForKey:@"actionList"];
        for (int j = 0; j < [actionList count]; j++) {
            if ([[[actionList objectAtIndex:j] objectForKey:@"actionQueue"] boolValue]) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (void)resetActionQueue
{
    for (int i = 0; i < [actionsGroupList count]; i++) {
        NSDictionary* group = [actionsGroupList objectAtIndex:i];
        NSArray* actionList = [group objectForKey:@"actionList"];
        for (int j = 0; j < [actionList count]; j++) {
            [[actionList objectAtIndex:j] setValue:[NSNumber numberWithBool:YES] forKey:@"actionQueue"];
        }
    }
}

- (float)userWeight
{
    NSNumber* item = [caloriesData objectForKey:@"weight"];
    if (item)
        return [item floatValue];
    
    return 0;
}

- (void)setUserWeight:(float)weight
{
    [caloriesData setObject:[NSNumber numberWithFloat:weight] forKey:@"weight"];
}

- (void)applyWeight
{
    // get user weight;
    float weight = [self userWeight] / 2.2;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSTimeInterval secondsPerDay = 24 * 60 * 60;
    NSDate* today = [NSDate date];
    NSString* day;
    NSNumber* item;
    
    for (int i = 0; i < 5; i++) {
        day = [formatter stringFromDate:[today dateByAddingTimeInterval:-secondsPerDay * i]];
        item = [caloriesData valueForKey:day];
        if (item != nil) {
            item = [NSNumber numberWithFloat:[item floatValue] * weight];
            [caloriesData setValue:item forKey:day];
        }

        day = [day stringByAppendingString:@"_sitting"];
        item = [caloriesData valueForKey:day];
        if (item != nil) {
            item = [NSNumber numberWithFloat:[item floatValue] * weight];
            [caloriesData setValue:item forKey:day];
        }
    }
}

- (void)loadCaloriesData
{
    // create data variable
    caloriesData = [[NSMutableDictionary alloc] initWithCapacity:11];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSTimeInterval secondsPerDay = 24 * 60 * 60;
    NSDate* today = [NSDate date];
    NSString* day;
    NSNumber* item;

    // load saved data
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *caloriesPath = [rootPath stringByAppendingPathComponent:@"calories.data"];
    NSDictionary* data = [NSDictionary dictionaryWithContentsOfFile:caloriesPath];
    
    if (data) {
        // set calories data for 5 days.
        for (int i = 0; i < 5; i++) {
            day = [formatter stringFromDate:[today dateByAddingTimeInterval:-secondsPerDay * i]];
            item = [data valueForKey:day];
            if (item != nil)
                [caloriesData setValue:item forKey:day];

            day = [day stringByAppendingString:@"_sitting"];
            item = [data valueForKey:day];
            if (item != nil)
                [caloriesData setValue:item forKey:day];
        }
        
        [caloriesData setObject:[data objectForKey:@"weight"] forKey:@"weight"];
    } else {
        [caloriesData setObject:[NSNumber numberWithFloat:0] forKey:@"weight"];
    }
}

- (void)saveCaloriesData
{
    // load saved data
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *caloriesPath = [rootPath stringByAppendingPathComponent:@"calories.data"];
    [caloriesData writeToFile:caloriesPath atomically:YES];
}

- (int)caloriesOfDate:(NSDate*)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSString* day = [formatter stringFromDate:date];
    NSNumber* item = [caloriesData valueForKey:day];
    if (item)
        return (int)([item floatValue] + 0.5);
    
    return 0;
}

- (int)caloriesBySittingOfDate:(NSDate*)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSString* day = [[formatter stringFromDate:date] stringByAppendingString:@"_sitting"];
    NSNumber* item = [caloriesData valueForKey:day];
    if (item)
        return (int)([item floatValue] + 0.5);
    
    return 0;
}

- (void)calcCalories
{
    // calc this exercise
    float currentCaloriesStandApp = 0;
    float currentCaloriesSittingDown = 0;
    float weight = [self userWeight] / 2.2;
    
    NSDictionary* action = [self currentAction];
    int time = [[action objectForKey:@"actionTime"] intValue];
    float met = [[action objectForKey:@"caloriesMET"] floatValue];

    if (weight > 0) {
        currentCaloriesStandApp = weight * met * time * 3.5 / 200;
        currentCaloriesSittingDown = weight * MET_FOR_SITTING * time * 3.5 / 200;
    } else {
        currentCaloriesStandApp = met * time * 3.5 / 200;
        currentCaloriesSittingDown = MET_FOR_SITTING * time * 3.5 / 200;
    }
    
    // get today calories
    float caloriesStandApp = 0;
    float caloriesSittingDown = 0;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSString* day = [formatter stringFromDate:[NSDate date]];
    NSNumber* item = [caloriesData valueForKey:day];
    if (item)
        caloriesStandApp = [item floatValue];
    
    // update
    caloriesStandApp += currentCaloriesStandApp;
    [caloriesData setValue:[NSNumber numberWithFloat:caloriesStandApp] forKey:day];
    
    // get today calories if sitting down
    day = [day stringByAppendingString:@"_sitting"];
    item = [caloriesData valueForKey:day];
    if (item)
        caloriesSittingDown = [item floatValue];
    
    // update
    caloriesSittingDown += currentCaloriesSittingDown;
    [caloriesData setValue:[NSNumber numberWithFloat:caloriesSittingDown] forKey:day];
}


@end
