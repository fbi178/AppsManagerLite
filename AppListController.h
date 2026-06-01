#import <UIKit/UIKit.h>

@interface AppListController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, strong) NSArray *apps;
@property (nonatomic, strong) NSArray *filteredApps;
@property (nonatomic, strong) UISearchController *searchController;
- (void)reloadApps;
@end
