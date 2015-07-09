//
//  ProgressViewController.h
//  StandupAlarm
//
//  Created by Albert Li on 10/18/12.
//
//

#import <UIKit/UIKit.h>
#import "GADBannerView.h"
#import "PCLineChartView.h"

@interface ProgressViewController : UIViewController
{
    GADBannerView *bannerView_;
}

@property (weak, nonatomic) IBOutlet UIView *lineChartContainer;
@property (nonatomic, strong) PCLineChartView *lineChartView;
@property (weak, nonatomic) IBOutlet UILabel *lblUserWeight;

- (void)loadProgressChart;
- (IBAction)backToMore:(id)sender;
- (IBAction)shareOnFacebook:(id)sender;
- (IBAction)editUserWeight:(id)sender;
- (void)doShareOnFacebook;

@end
