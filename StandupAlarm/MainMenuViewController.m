//
//  MainMenuViewController.m
//  StandupAlarm
//
//  Created by Apple Fan on 6/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MainMenuViewController.h"
#import "CountingEngine.h"
#import "Config.h"
#import "IntervalCell.h"
#import <QuartzCore/QuartzCore.h>

@interface MainMenuViewController ()

@end

@implementation MainMenuViewController

@synthesize intervalTable;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)popViewController:(UIButton*)sender
{
    if ([[self.navigationController viewControllers] count] > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self performSegueWithIdentifier:@"Main2Home" sender:self];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIGraphicsBeginImageContextWithOptions(self.view.frame.size, NO, 0);
    [iPhoneImage(@"commonbg.png") drawInRect:self.view.bounds];
    UIImage *bgImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self.view setBackgroundColor:[UIColor colorWithPatternImage:bgImage]];
    
    UIButton *backButton = [[UIButton alloc] init];
    [backButton setImage:[UIImage imageNamed:@"back.png"] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(popViewController:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backButton];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    [titleLabel setBackgroundColor:[UIColor clearColor]];
    [titleLabel setTextColor:[UIColor whiteColor]];
    [titleLabel setTextAlignment:UITextAlignmentCenter];
    [titleLabel setText:self.navigationItem.title];
    titleLabel.layer.transform = CATransform3DMakeScale(0.5, 1.0, 1.0);
    [self.view addSubview:titleLabel];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [backButton setFrame:CGRectMake(20, 18, 119, 72)];
        [titleLabel setFrame:CGRectMake(0, 0, 768, 107)];
        [titleLabel setFont:[UIFont systemFontOfSize:72]];
    } else {
        [backButton setFrame:CGRectMake(4, 8, 50, 30)];
        [titleLabel setFrame:CGRectMake(0, 0, 320, 45)];
        [titleLabel setFont:[UIFont systemFontOfSize:30]];
    }

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
    
    // load interval list
    NSString* plistPath = [[NSBundle mainBundle] pathForResource:@"Interval" ofType:@"plist"];
    intervalList = [NSArray arrayWithContentsOfFile:plistPath];
    
    // load saved interval
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    plistPath = [rootPath stringByAppendingPathComponent:@"firstlunch.inf"];
    
    NSArray* lunchData = [NSArray arrayWithContentsOfFile:plistPath];
    if (lunchData) {
        currentInterval = [[lunchData objectAtIndex:0] intValue];
//        [intervalTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:currentInterval inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    } else {
        currentInterval = DEFAULT_INTERVAL;
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    
    bannerView_.delegate = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)startButtonClicked:(id)sender
{
    int interval = [[[intervalList objectAtIndex:currentInterval] objectForKey:@"interval"] intValue];

    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [rootPath stringByAppendingPathComponent:@"firstlunch.inf"];
    
    NSArray* intervalArray = [NSArray arrayWithObjects:[NSNumber numberWithInt:currentInterval], nil];
    [intervalArray writeToFile:plistPath atomically:YES];

#if !USE_TEST_TIME
    [[CountingEngine getInstance] startCountingWithInterval:interval * 60 scheduleType:0 resetInterval:YES];
#else
    [[CountingEngine getInstance] startCountingWithInterval:interval / 3 scheduleType:0 resetInterval:YES];
#endif

    [self performSegueWithIdentifier:@"StartCounting" sender:self];
}


#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    IntervalCell *cell;
    cell = (IntervalCell*)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:currentInterval inSection:0]];
    [cell setChecked:NO];
    
    currentInterval = indexPath.row;
    cell = (IntervalCell*)[tableView cellForRowAtIndexPath:indexPath];
    [cell setChecked:YES];
    
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}


#pragma mark -
#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *INTERVAL_CELL = @"IntervalCell";
    
    IntervalCell *cell = (IntervalCell*)[tableView dequeueReusableCellWithIdentifier:INTERVAL_CELL];
    if (cell == nil) {
        cell = [[IntervalCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:INTERVAL_CELL];
    }
    
    [cell setChecked:(currentInterval == indexPath.row)];
    [cell setCaption:[[intervalList objectAtIndex:indexPath.row] objectForKey:@"caption"]];
    [cell setHealth:[[[intervalList objectAtIndex:indexPath.row] objectForKey:@"health"] intValue]];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [intervalList count];
}

@end
