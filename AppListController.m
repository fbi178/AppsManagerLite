#import "AppListController.h"
#import "AppTableViewCell.h"
#import "ApplicationItem.h"
#import "AppDetailController.h"

@implementation AppListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"应用";
    self.navigationController.navigationBar.translucent = NO;
    
    // 刷新按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(reloadApps)];
    
    // 搜索
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    
    // 注册 Cell
    [self.tableView registerClass:[AppTableViewCell class] forCellReuseIdentifier:@"AppCell"];
    self.tableView.rowHeight = 64;
    self.tableView.tableFooterView = [[UIView alloc] init];
    
    // 加载应用列表
    [self loadApps];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadApps];
}

- (void)loadApps {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *apps = [ApplicationItem allInstalledApps];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.apps = apps;
            [self.tableView reloadData];
        });
    });
}

- (void)reloadApps {
    [self loadApps];
}

#pragma mark - TableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.isFiltering ? self.filteredApps.count : self.apps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AppTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppCell" forIndexPath:indexPath];
    ApplicationItem *item = self.isFiltering ? self.filteredApps[indexPath.row] : self.apps[indexPath.row];
    [cell configureWithItem:item];
    return cell;
}

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ApplicationItem *item = self.isFiltering ? self.filteredApps[indexPath.row] : self.apps[indexPath.row];
    AppDetailController *detailVC = [[AppDetailController alloc] initWithAppItem:item];
    [self.navigationController pushViewController:detailVC animated:YES];
}

#pragma mark - Search

- (BOOL)isFiltering {
    return self.searchController.isActive && self.searchController.searchBar.text.length > 0;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = searchController.searchBar.text;
    if (!self.apps || text.length == 0) {
        self.filteredApps = nil;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"appName CONTAINS[cd] %@ OR bundleId CONTAINS[cd] %@", text, text];
        self.filteredApps = [self.apps filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

@end
