#import <UIKit/UIKit.h>
@class ApplicationItem;

@interface AppDetailController : UITableViewController
- (instancetype)initWithAppItem:(ApplicationItem *)item;
@property (nonatomic, strong) ApplicationItem *appItem;
@end
