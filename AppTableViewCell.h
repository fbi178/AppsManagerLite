#import <UIKit/UIKit.h>
@class ApplicationItem;

@interface AppTableViewCell : UITableViewCell
@property (nonatomic, strong) UIImageView *appIconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *bundleIdLabel;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) ApplicationItem *item;
- (void)configureWithItem:(ApplicationItem *)item;
@end
