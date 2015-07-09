//
//  ExerciseViewController.h
//  StandupAlarm
//
//  Created by Apple Fan on 6/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "GADBannerView.h"
#import "CountingClockView.h"
#import "StoreFlyerViewController.h"

@interface ExerciseViewController : UIViewController
{
    NSTimer* ledIndicatorTimer;
    GADBannerView *bannerView_;
}

@property (nonatomic, weak) IBOutlet UIView* videoRegion;

#ifdef USE_HTMLDESCRIPTION
@property (nonatomic, weak) IBOutlet UIWebView* exerciseDescription;
#endif

@property (nonatomic, weak) IBOutlet UILabel *ledIndicator;
@property (nonatomic, weak) IBOutlet CountingClockView* countingClock;

@property (nonatomic, weak) IBOutlet UIButton* domoreButton;
@property (nonatomic, weak) IBOutlet UIButton* snoozeButton;
@property (nonatomic, weak) IBOutlet UIProgressView* snoozeProgress;

@property (atomic, strong) StoreFlyerViewController* storeFlyerViewController;
@property (atomic, strong) MPMoviePlayerController *mpc;

@property (nonatomic, assign) BOOL scheduledExercise;

- (IBAction)replayVideo:(id)sender;

- (void)checkScheduleTimer;

- (void)viewControllerDidBecomeActive;

- (IBAction)skipExercise:(id)sender;

- (IBAction)clickDoMoreButton:(id)sender;

- (IBAction)snoozeExcercise;

- (void)loadExerciseData;

- (void)stopExercise;

- (void)playbackDidFinish:(NSNotification *)notification;

- (void)pauseExercise;

@end
