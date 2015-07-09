//
//  HomeViewController.h
//  StandupAlarm
//
//  Created by Albert Li on 4/28/13.
//
//

#import <UIKit/UIKit.h>
#import "GADBannerView.h"

@interface HomeViewController : UIViewController
{
    GADBannerView *bannerView_;
}

- (IBAction)showProgress:(id)sender;

@end
