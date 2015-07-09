//
//  CountingViewController.h
//  StandupAlarm
//
//  Created by Apple Fan on 6/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GADBannerView.h"
#import "CountingClockView.h"

@interface CountingViewController : UIViewController
{
    NSTimer __strong * ledIndicatorTimer;
    GADBannerView *bannerView_;
}

@property (nonatomic, weak) IBOutlet UILabel *ledIndicator;
@property (nonatomic, weak) IBOutlet CountingClockView* countingClock;
@property (nonatomic, weak) IBOutlet UIButton* pauseResumeButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (nonatomic, strong) NSNumber* resumeFlag;

- (void)viewControllerWillEnterForeground;

- (IBAction)pauseResumeButtonClicked:(id)sender;

- (IBAction)stopButtonClicked:(id)sender;

- (void)updateLedIndicator;

@end
