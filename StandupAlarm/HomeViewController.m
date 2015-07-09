//
//  HomeViewController.m
//  StandupAlarm
//
//  Created by Albert Li on 4/28/13.
//
//

#import "HomeViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "Config.h"
#import "CountingEngine.h"
#import "AppDelegate.h"
#import "ExerciseViewController.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

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
    [iPhoneImage(@"homebg.png") drawInRect:self.view.bounds];
    UIImage *bgImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self.view setBackgroundColor:[UIColor colorWithPatternImage:bgImage]];
    
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

    [self  checkScheduledAlarm];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)checkScheduledAlarm
{
    AppDelegate *appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    
    if (appDelegate.localNotification) {
        int notificationType = [[appDelegate.localNotification.userInfo objectForKey:kNotificationTypeKey] intValue];
        
        if (notificationType == 10) {
            int alarmExercise = [[appDelegate.localNotification.userInfo objectForKey:kNotificationExerciseKey] intValue];
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
            [self.navigationController pushViewController:exerciseViewController animated:YES];
        }
    }
}

- (IBAction)showProgress:(id)sender {
    CountingEngine *engine = [CountingEngine getInstance];
    if ([engine userWeight] == 0) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:nil message:@"Please input  your weight (lbs)!" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField * alertTextField = [alert textFieldAtIndex:0];
        alertTextField.keyboardType = UIKeyboardTypeDecimalPad;
        [alert show];
        return;
    }

    [self performSegueWithIdentifier:@"showProgress" sender:self];
}

#pragma mark - alertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    // click OK
    if (buttonIndex == 1) {
        // get inputed weight
        NSString* weightText = [[alertView textFieldAtIndex:0] text];
        if (weightText && [weightText floatValue] > 0) {
            
            CountingEngine *engine = [CountingEngine getInstance];
            
            // set user weight
            [engine setUserWeight:[weightText floatValue]];
            [engine applyWeight];
            [engine saveCaloriesData];
            
            // show progress chart
            [self performSegueWithIdentifier:@"showProgress" sender:self];
        } else {
            // retry input
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle:nil message:@"Please input  your weight (lbs)!" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            UITextField * alertTextField = [alert textFieldAtIndex:0];
            alertTextField.keyboardType = UIKeyboardTypeDecimalPad;
            [alert show];
            return;
        }
    }
}

@end
