#import "AppListController.h"
#import "AppTableViewCell.h"
#import "ApplicationItem.h"
#import "AppDetailController.h"

@implementation AppListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"应用";
    self.navigationController.navigationBar.translucent = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadApps)];
    [self.tableView registerClass:[AppTableViewCell class] forCellReuseIdentifier:@"AppCell"];
    self.tableView.rowHeight = 64;
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self loadApps];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
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

- (void)reloadApps { [self loadApps]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.apps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AppTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppCell" forIndexPath:indexPath];
    [cell configureWithItem:self.apps[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    AppDetailController *detailVC = [[AppDetailController alloc] initWithAppItem:self.apps[indexPath.row]];
    [self.navigationController pushViewController:detailVC animated:YES];
}

@end
