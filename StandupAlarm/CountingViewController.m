//
//  CountingViewController.m
//  StandupAlarm
//
//  Created by Apple Fan on 6/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CountingViewController.h"
#import "CountingEngine.h"
#import <QuartzCore/CAAnimation.h>
#import "Config.h"
#import "MoreViewController.h"
#import "ExerciseViewController.h"

@implementation CountingViewController

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

    UIGraphicsBeginImageContextWithOptions(self.view.frame.size, NO, 0);
    [iPhoneImage(@"commonbg.png") drawInRect:self.view.bounds];
    UIImage *bgImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self.view setBackgroundColor:[UIColor colorWithPatternImage:bgImage]];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    [titleLabel setBackgroundColor:[UIColor clearColor]];
    [titleLabel setTextColor:[UIColor whiteColor]];
    [titleLabel setTextAlignment:UITextAlignmentCenter];
    [titleLabel setText:self.navigationItem.title];
    titleLabel.layer.transform = CATransform3DMakeScale(0.5, 1.0, 1.0);
    [self.view addSubview:titleLabel];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [titleLabel setFrame:CGRectMake(0, 0, 768, 107)];
        [titleLabel setFont:[UIFont systemFontOfSize:72]];
    } else {
        [titleLabel setFrame:CGRectMake(0, 0, 320, 45)];
        [titleLabel setFont:[UIFont systemFontOfSize:30]];
    }
    
    [self.ledIndicator setFont:[UIFont fontWithName:@"BebasNeue" size:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 96.0 : 60.0]];
    [self.descriptionLabel setFont:[UIFont fontWithName:@"BebasNeue" size:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 24.0 : 15.0]];
    
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
    [self setStopButton:nil];
    [self setDescriptionLabel:nil];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    CountingEngine* engine = [CountingEngine getInstance];
    if (self.resumeFlag && [self.resumeFlag boolValue]) {
        [engine resumeCounting];
        self.resumeFlag = nil;
    }

    [self.ledIndicator setText:[engine getRemainingTimeString]];
    ledIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 target:self selector:@selector(updateLedIndicator) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (ledIndicatorTimer != nil) {
        // stop timer
        [ledIndicatorTimer invalidate];
        ledIndicatorTimer = nil;
    }
}

- (void)viewControllerWillEnterForeground
{
    CountingEngine* engine = [CountingEngine getInstance];
    [self.ledIndicator setText:[engine getRemainingTimeString]];
    [self.countingClock setProgressValue:[engine getPassRate]];
    [self.countingClock setNeedsDisplay];
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)pauseResumeButtonClicked:(id)sender
{
    CountingEngine* engine = [CountingEngine getInstance];

    if ([engine isPaused]) {
        [engine resumeCounting];
        [self.pauseResumeButton setTitle:@"Pause" forState:UIControlStateNormal];
        [self.pauseResumeButton setImage:[UIImage imageNamed:@"MenuItem_Pause"] forState:UIControlStateNormal];
    } else {
        [engine pauseCounting];
        [self.pauseResumeButton setTitle:@"Resume" forState:UIControlStateNormal];
        [self.pauseResumeButton setImage:[UIImage imageNamed:@"MenuItem_Resume"] forState:UIControlStateNormal];
    }
}

- (IBAction)stopButtonClicked:(id)sender
{
    [ledIndicatorTimer invalidate];
    ledIndicatorTimer = nil;
    
    [[CountingEngine getInstance] stopCounting];
    
    [self performSegueWithIdentifier:@"StopCounting" sender:self];
}

- (void)updateLedIndicator
{
    CountingEngine* engine = [CountingEngine getInstance];
    
    // check if is reached the target
    if ([engine isReachedTarget]) {
        // stop timer
        [ledIndicatorTimer invalidate];
        ledIndicatorTimer = nil;
        
        // stop engine
        [engine stopCounting];
        
        // show exercise window
        [self performSegueWithIdentifier:@"startingExercise" sender:self];
    } else {
        // update watch
        [self.ledIndicator setText:[engine getRemainingTimeString]];
        [self.countingClock setProgressValue:[engine getPassRate]];
        [self.countingClock setNeedsDisplay];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"startingExercise"]) {
        ExerciseViewController* exerciseViewController = segue.destinationViewController;
        [exerciseViewController setScheduledExercise:NO];
//        [self.navigationController popViewControllerAnimated:YES];
    } else if ([[segue identifier] isEqualToString:@"showMore"]) {
        CountingEngine* engine = [CountingEngine getInstance];
        if (![engine isPaused]) {
            [engine pauseCounting];
            self.resumeFlag = [NSNumber numberWithBool:YES];
        } else {
            self.resumeFlag = [NSNumber numberWithBool:NO];
        }
    }
}

@end
