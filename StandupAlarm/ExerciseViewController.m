//
//  ExerciseViewController.m
//  StandupAlarm
//
//  Created by Apple Fan on 6/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ExerciseViewController.h"
#import <QuartzCore/CAAnimation.h>
#import <AVFoundation/AVAudioSession.h>
#import "CountingEngine.h"
#import "CountingViewController.h"
#import "Config.h"

@implementation ExerciseViewController

@synthesize videoRegion;

#ifdef USE_HTMLDESCRIPTION
@synthesize exerciseDescription;
#endif

@synthesize ledIndicator;
@synthesize countingClock;

@synthesize domoreButton;
@synthesize snoozeButton;
@synthesize snoozeProgress;

NSString* const actionFolder = @"data";

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self loadExerciseData];
    
    [ledIndicator setText:[[CountingEngine getInstance] getRemainingTimeString]];
    ledIndicator.font = [UIFont fontWithName:@"BebasNeue" size:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 40.0 : 25.0];
    ledIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 target:self selector:@selector(updateLedIndicator) userInfo:nil repeats:YES];

#if USE_ADMOB
    // Create a view of the standard size at the bottom of the screen.
    // Available AdSize constants are explained in GADAdSize.h.
    CGSize adSize;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        adSize = GAD_SIZE_728x90;
    } else {
        adSize = GAD_SIZE_320x50;
    }
    
    bannerView_ = [[GADBannerView alloc] initWithFrame:CGRectMake((self.view.frame.size.width - adSize.width) / 2,
                                                                  self.view.frame.size.height - adSize.height,
                                                                  adSize.width,
                                                                  adSize.height)];
    // Specify the ad's "unit identifier." This is your AdMob Publisher ID.
    bannerView_.adUnitID = @"a14ff3a14d8de5d";
    
    // Let the runtime know which UIViewController to restore after taking
    // the user wherever the ad goes and add it to the view hierarchy.
    bannerView_.rootViewController = self;
    [self.view addSubview:bannerView_];
    
    // Initiate a generic request to load it with an ad.
    [bannerView_ loadRequest:[GADRequest request]];
#endif
}

- (void)viewDidUnload
{
    [self stopExercise];
    
    [ledIndicatorTimer invalidate];
    ledIndicatorTimer = nil;

    self.storeFlyerViewController = nil;
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [ledIndicator setText:[[CountingEngine getInstance] getRemainingTimeString]];

    if ([[CountingEngine getInstance] restartFlag]) {
        [[CountingEngine getInstance] setRestartFlag:NO];
        [self stopExercise];
        [self loadExerciseData];
    }
    
//    [ledIndicator setText:[[CountingEngine getInstance] getRemainingTimeString]];
//    ledIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 target:self selector:@selector(updateLedIndicator) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
//    [self stopExercise];

//    [ledIndicatorTimer invalidate];
//    ledIndicatorTimer = nil;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)replayVideo:(id)sender {
    [self.mpc setCurrentPlaybackTime:0];
    [self.mpc play];
}

- (void)checkScheduleTimer
{
    if (![snoozeButton isSelected]) {
        CountingEngine* engine = [CountingEngine getInstance];
        
        if ([engine isReachedTarget] && (GETCURRENTTIME >= engine.targetTime + engine.nextTargetInterval)) {
            // update watch
#if !USE_TEST_TIME
            
            NSDictionary* action = [engine currentAction];
            
            int exerciseTime = [[action objectForKey:@"actionTime"] intValue] * 60;
            [ledIndicator setText:[NSString stringWithFormat:@"%02d:%02d", exerciseTime / 60, exerciseTime % 60]];
#else
            [ledIndicator setText:[NSString stringWithFormat:@"%02d:%02d", TEST_EXERCISE_TIME / 60, TEST_EXERCISE_TIME % 60]];
#endif
            
            [countingClock setProgressValue:0];
            [countingClock setNeedsDisplay];
            
#if !USE_TEST_TIME
            [engine startCountingWithInterval:[[action objectForKey:@"actionTime"] intValue] * 60 scheduleType:1 resetInterval:NO];
#else
            [engine startCountingWithInterval:TEST_EXERCISE_TIME scheduleType:1 resetInterval:NO];
#endif
            
            [self.mpc setCurrentPlaybackTime:0];
            
        }
    }
}

- (void)viewControllerDidBecomeActive
{
    [self.mpc play];
}

- (IBAction)skipExercise:(id)sender {
    CountingEngine* engine = [CountingEngine getInstance];
    
    [self stopExercise];
    
    // stop timer
    [ledIndicatorTimer invalidate];
    ledIndicatorTimer = nil;
    
    // stop engine
    [engine stopCounting];
    
    [engine setAdCounter:[engine adCounter] + 1];

    // back view controller
    if ([[self.navigationController viewControllers] count] > 1 && self.scheduledExercise) {
 
        [self.navigationController popViewControllerAnimated:YES];

    } else {
        
        // start new counting timer
        [engine startCounting];

        // show counting window
        [self performSegueWithIdentifier:@"Back2Counting" sender:self];
    }
}

- (IBAction)clickDoMoreButton:(id)sender
{
    [self pauseExercise];
    
#ifdef FREEVERSION
    NSString* storyboardName = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"MainStoryboard_Free_iPad" : @"MainStoryboard_Free_iPhone";
#else
    NSString* storyboardName = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"MainStoryboard_iPad" : @"MainStoryboard_iPhone";
#endif
    if (isPhone568)
        storyboardName = [storyboardName stringByAppendingString:@"_568h"];
    
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
    self.storeFlyerViewController = (StoreFlyerViewController*)[storyboard instantiateViewControllerWithIdentifier:@"storeFlyerViewController"];
    self.storeFlyerViewController.exerciseViewController = self;
    self.storeFlyerViewController.playWhenResume = ([self.mpc playbackState] ==  MPMoviePlaybackStatePlaying);
    
    [self.mpc pause];
    [self.view addSubview:self.storeFlyerViewController.view];
}

- (IBAction)snoozeExcercise
{
    [snoozeButton setSelected:![snoozeButton isSelected]];
    
    CountingEngine* engine = [CountingEngine getInstance];
    if ([snoozeButton isSelected]) {
        [snoozeButton setImage:[UIImage imageNamed:@"unsnooze.png"] forState:UIControlStateNormal];
        [snoozeButton setImage:[UIImage imageNamed:@"unsnooze.png"] forState:UIControlStateHighlighted];
        
        [snoozeProgress setProgress:0];
        [snoozeProgress setHidden:NO];
        
        NSDictionary* action = [engine currentAction];
        // update watch
#if !USE_TEST_TIME
        int exerciseTime = [[action objectForKey:@"actionTime"] intValue] * 60;
        [ledIndicator setText:[NSString stringWithFormat:@"%02d:%02d", exerciseTime / 60, exerciseTime % 60]];
#else
        [ledIndicator setText:[NSString stringWithFormat:@"%02d:%02d", TEST_EXERCISE_TIME / 60, TEST_EXERCISE_TIME % 60]];
#endif

        [countingClock setProgressValue:0];
        [countingClock setNeedsDisplay];

#if !USE_TEST_TIME
        [engine startCountingWithInterval:SNOOZE_TIME scheduleType:2 resetInterval:NO];
#else
        [engine startCountingWithInterval:TEST_SNOOZE_TIME scheduleType:2 resetInterval:NO];
#endif
        
        [self.mpc setCurrentPlaybackTime:[[action objectForKey:@"pauseTime"] intValue]];
        [self.mpc pause];
    } else {
        [snoozeButton setImage:[UIImage imageNamed:@"snooze.png"] forState:UIControlStateNormal];
        [snoozeButton setImage:nil forState:UIControlStateHighlighted];
        
        [snoozeProgress setHidden:YES];
        
        [engine stopCounting];
        
        [self.mpc setCurrentPlaybackTime:0];
        [self.mpc play];
        
#if !USE_TEST_TIME
        int exerciseTime = [[[engine currentAction] objectForKey:@"actionTime"] intValue] * 60;
        [engine startCountingWithInterval:exerciseTime scheduleType:1 resetInterval:NO];
#else
        [engine startCountingWithInterval:TEST_EXERCISE_TIME scheduleType:1 resetInterval:NO];
#endif
    }
}

- (void)loadExerciseData
{
    NSDictionary* action = [[CountingEngine getInstance] currentAction];

#ifdef USE_HTMLDESCRIPTION  
    // show description
    NSString* htmlFile = [[NSBundle mainBundle] pathForResource:[@"data" stringByAppendingPathComponent:[action objectForKey:@"actionFile"]] ofType:@"html"];
    NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
    [exerciseDescription loadHTMLString:htmlString baseURL:nil];
    
    for (id subview in exerciseDescription.subviews){
        if ([[subview class] isSubclassOfClass: [UIScrollView class]]){
			((UIScrollView *)subview).bounces = NO;
        }
    }
#endif
    
#if !USE_TEST_TIME
    [[CountingEngine getInstance] startCountingWithInterval:[[action objectForKey:@"actionTime"] intValue] * 60 scheduleType:1 resetInterval:NO];
#else
    [[CountingEngine getInstance] startCountingWithInterval:TEST_EXERCISE_TIME scheduleType:1 resetInterval:NO];
#endif
    
    // path for video
    NSString *path = [[NSBundle mainBundle] pathForResource:[@"data" stringByAppendingPathComponent:[action objectForKey:@"actionFile"]] ofType:@"mp4"];
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    // create movie player
    self.mpc = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:path]];
    [self.mpc setControlStyle:MPMovieControlStyleNone];
    [self.mpc setScalingMode:MPMovieScalingModeFill];
    [self.mpc setUseApplicationAudioSession:YES];
    [self.mpc prepareToPlay];
    
    [self.mpc.view setFrame:[videoRegion bounds]];
    [videoRegion addSubview:self.mpc.view];
    
    [self.mpc play];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.mpc];
}

- (void)stopExercise
{
    [self.mpc stop];
    self.mpc = nil;
}

- (void)updateLedIndicator
{
    CountingEngine* engine = [CountingEngine getInstance];
    
    if (![snoozeButton isSelected]) {
        // check if is reached the target
        if ([engine isReachedTarget]) {
            // When clicking local notification to stand after time to back work .
            if (GETCURRENTTIME >= engine.targetTime + engine.nextTargetInterval) {
                
                // select new exercise
                [engine setCurrentActionRandomly];
            
                NSDictionary *action = [engine currentAction];
                [action setValue:[NSNumber numberWithBool:NO] forKey:@"actionQueue"];
                
                if ([engine isEmeptyActionQueue]) {
                    [engine resetActionQueue];
                    [action setValue:[NSNumber numberWithBool:NO] forKey:@"actionQueue"];
                }
            
                [[CountingEngine getInstance] saveActionList];

                // update watch
#if !USE_TEST_TIME
                
                int exerciseTime = [[action objectForKey:@"actionTime"] intValue] * 60;
                [ledIndicator setText:[NSString stringWithFormat:@"%02d:%02d", exerciseTime / 60, exerciseTime % 60]];
#else
                [ledIndicator setText:[NSString stringWithFormat:@"%02d:%02d", TEST_EXERCISE_TIME / 60, TEST_EXERCISE_TIME % 60]];
#endif
                
                [countingClock setProgressValue:0];
                [countingClock setNeedsDisplay];
                
#if !USE_TEST_TIME
                [engine startCountingWithInterval:[[action objectForKey:@"actionTime"] intValue] * 60 scheduleType:1 resetInterval:NO];
#else
                [engine startCountingWithInterval:TEST_EXERCISE_TIME scheduleType:1 resetInterval:NO];
#endif
                
                // path for video
                NSString *path = [[NSBundle mainBundle] pathForResource:[@"data" stringByAppendingPathComponent:[action objectForKey:@"actionFile"]] ofType:@"mp4"];
                
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
                [[AVAudioSession sharedInstance] setActive:YES error:nil];
                
                // create movie player
                [self.mpc setContentURL:[NSURL fileURLWithPath:path]];
                [self.mpc prepareToPlay];
                [self.mpc play];

                [self.mpc setCurrentPlaybackTime:0];
                
            } else {
                
                // calc burned calories
                [engine calcCalories];
                [engine saveCaloriesData];
                
                // stop timer
                [ledIndicatorTimer invalidate];
                ledIndicatorTimer = nil;
                
                // stop engine
                [engine stopCounting];
                
                [engine setAdCounter:[engine adCounter] + 1];
                
                // back view controller
                if ([[self.navigationController viewControllers] count] > 1 && self.scheduledExercise) {

                    [self.navigationController popViewControllerAnimated:YES];

                } else {
                    
                    // start new counting timer
                    [engine startCounting];

                    // show counting window
                    [self performSegueWithIdentifier:@"Back2Counting" sender:self];
                }
            }
        } else {
            // update watch
            [ledIndicator setText:[engine getRemainingTimeString]];
            [countingClock setProgressValue:[engine getPassRate]];
            [countingClock setNeedsDisplay];
        }
    } else {
        // check if snooze time is riched.
        if ([engine isReachedTarget]) {
            [snoozeButton setSelected:NO];
            
            [snoozeButton setImage:[UIImage imageNamed:@"snooze.png"] forState:UIControlStateNormal];
            [snoozeButton setImage:nil forState:UIControlStateHighlighted];
            
            [snoozeProgress setHidden:YES];
            
            [engine stopCounting];
            
            [self.mpc setCurrentPlaybackTime:0];
            [self.mpc play];
            
#if !USE_TEST_TIME
            int exerciseTime = [[[engine currentAction] objectForKey:@"actionTime"] intValue] * 60;
            [engine startCountingWithInterval:exerciseTime scheduleType:1 resetInterval:NO];
#else
            [engine startCountingWithInterval:TEST_EXERCISE_TIME scheduleType:1 resetInterval:NO];
#endif
        } else {
            [snoozeProgress setProgress:[engine getPassRate] animated:YES];
        }
    }
}

- (void)playbackDidFinish:(NSNotification *)notification {
//    MPMoviePlayerController *player = [notification object];
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:player];
    
//    [player stop];
    
    NSDictionary *userInfo = [notification userInfo]; // Check the finish reson
    if ([[userInfo objectForKey:@"MPMoviePlayerPlaybackDidFinishReasonUserInfoKey"] intValue] != MPMovieFinishReasonUserExited) {
        NSDictionary* action = [[CountingEngine getInstance] currentAction];
        [self.mpc setCurrentPlaybackTime:[[action objectForKey:@"pauseTime"] intValue]];
    }
}

- (void)pauseExercise
{
    [snoozeButton setSelected:NO];
    
    [snoozeButton setImage:[UIImage imageNamed:@"snooze.png"] forState:UIControlStateNormal];
    [snoozeButton setImage:nil forState:UIControlStateHighlighted];
    
    [snoozeProgress setHidden:YES];
    
    [[CountingEngine getInstance] pauseCounting];

//    [self.mpc pause];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"ListSegue"]) {
        [self pauseExercise];
    }
}

@end
