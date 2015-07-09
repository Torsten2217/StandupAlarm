//
//  MainMenuViewController.h
//  StandupAlarm
//
//  Created by Apple Fan on 6/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GADBannerView.h"

@interface MainMenuViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
{
    GADBannerView *bannerView_;
    NSArray* intervalList;
    int currentInterval;
}

@property (nonatomic, weak) IBOutlet UITableView* intervalTable;

- (IBAction)startButtonClicked:(id)sender;

@end
