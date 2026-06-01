#import "BackupsListController.h"
#import "BackupFileManager.h"
#import "BackupManager.h"

@interface BackupsListController ()
@property (nonatomic, strong) NSMutableDictionary *allBackups; // bundleId → [backupDicts]
@property (nonatomic, strong) NSArray *allBundleIds;
@end

@implementation BackupsListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"备份";
    self.navigationController.navigationBar.translucent = NO;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(reloadData)];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    self.tableView.tableFooterView = [[UIView alloc] init];
    
    [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)reloadData {
    self.allBackups = [NSMutableDictionary dictionary];
    NSString *rootPath = [[BackupFileManager sharedInstance] backupRootPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSArray *bundleDirs = [fm contentsOfDirectoryAtPath:rootPath error:nil];
    for (NSString *bundleId in bundleDirs) {
        NSString *listPath = [[rootPath stringByAppendingPathComponent:bundleId] stringByAppendingPathComponent:@"Backups.plist"];
        NSArray *backups = [NSArray arrayWithContentsOfFile:listPath];
        if (backups.count > 0) {
            self.allBackups[bundleId] = backups;
        }
    }
    
    self.allBundleIds = [self.allBackups.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.tableView reloadData];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.allBundleIds.count > 0 ? self.allBundleIds.count : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.allBundleIds.count == 0) return 1;
    NSString *bundleId = self.allBundleIds[section];
    return [self.allBackups[bundleId] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.allBundleIds.count == 0) return nil;
    return self.allBundleIds[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    if (self.allBundleIds.count == 0) {
        cell.textLabel.text = @"暂无备份";
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor grayColor];
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    
    NSString *bundleId = self.allBundleIds[indexPath.section];
    NSDictionary *backup = self.allBackups[bundleId][indexPath.row];
    
    cell.textLabel.text = backup[@"name"] ?: backup[@"date"] ?: @"未知备份";
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.textLabel.textColor = [UIColor blackColor];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ | v%@", backup[@"date"] ?: @"", backup[@"version"] ?: @""];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.allBundleIds.count == 0) return;
    
    // 显示备份详情
    NSString *bundleId = self.allBundleIds[indexPath.section];
    NSDictionary *backup = self.allBackups[bundleId][indexPath.row];
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"备份详情"
                                                                message:[NSString stringWithFormat:@"应用: %@\n版本: %@\n时间: %@\n设备: %@\n系统: %@",
                                                                         backup[@"appName"] ?: bundleId,
                                                                         backup[@"version"] ?: @"",
                                                                         backup[@"date"] ?: @"",
                                                                         backup[@"deviceName"] ?: @"",
                                                                         backup[@"systemVersion"] ?: @""]
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"删除备份" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self deleteBackup:bundleId backup:backup indexPath:indexPath];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)deleteBackup:(NSString *)bundleId backup:(NSDictionary *)backup indexPath:(NSIndexPath *)indexPath {
    NSString *backupId = backup[@"backupId"];
    NSString *filePath = [[BackupFileManager sharedInstance] backupFilePathForBundleId:bundleId backupId:backupId];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    
    // 更新列表
    NSMutableArray *list = [[[BackupFileManager sharedInstance] loadBackupListForBundleId:bundleId] mutableCopy];
    [list removeObject:backup];
    [[BackupFileManager sharedInstance] saveBackupList:list forBundleId:bundleId];
    
    [self reloadData];
}

@end
