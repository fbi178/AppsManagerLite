#import "AppDetailController.h"
#import "ApplicationItem.h"
#import "BackupManager.h"
#import "IDFVManager.h"

@interface AppDetailController ()
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) BackupManager *backupManager;
@property (nonatomic, strong) NSArray *backups;
@end

@implementation AppDetailController

- (instancetype)initWithAppItem:(ApplicationItem *)item {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _appItem = item;
        _backupManager = [BackupManager sharedInstance];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.appItem.appName;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DetailCell"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshBackups];
    [self buildSections];
    [self.tableView reloadData];
}

- (void)refreshBackups {
    self.backups = [self.backupManager backupsForApp:self.appItem.bundleId];
}

- (void)buildSections {
    self.sections = [NSMutableArray array];
    
    // Section 0: App 信息
    NSArray *infoRows = @[
        @{@"title": @"名称", @"value": self.appItem.appName},
        @{@"title": @"Bundle ID", @"value": self.appItem.bundleId},
        @{@"title": @"版本", @"value": self.appItem.version},
        @{@"title": @"容器路径", @"value": self.appItem.dataContainerPath ?: @"无"},
    ];
    [self.sections addObject:@{@"title": @"应用信息", @"rows": infoRows}];
    
    // Section 1: 操作
    NSArray *actionRows = @[
        @{@"title": @"备份数据", @"action": @"backup", @"color": @0},
        @{@"title": @"恢复数据", @"action": @"restore", @"color": @1},
        @{@"title": @"抹除数据", @"action": @"wipe", @"color": @2},
    ];
    [self.sections addObject:@{@"title": @"操作", @"rows": actionRows}];
    
    // Section 2: IDFV/IDFA
    IDFVManager *idfvMgr = [IDFVManager sharedInstance];
    if (idfvMgr.backupIDFVEnabled && idfvMgr.backupIDFAEnabled) {
        NSString *idfv = [IDFVManager readIDFVForBundleId:self.appItem.bundleId];
        NSString *idfa = [IDFVManager readIDFAForBundleId:self.appItem.bundleId];
        [self.sections addObject:@{@"title": @"设备标识", @"rows": @[
            @{@"title": @"IDFV", @"value": idfv ?: @"未备份"},
            @{@"title": @"IDFA", @"value": idfa ?: @"未备份"},
        ]}];
    }
    
    // Section 3: 备份列表
    if (self.backups.count > 0) {
        NSMutableArray *backupRows = [NSMutableArray array];
        for (NSDictionary *b in self.backups) {
            [backupRows addObject:@{
                @"title": b[@"name"] ?: @"未知",
                @"value": b[@"date"] ?: @"",
                @"backupFile": b
            }];
        }
        [self.sections addObject:@{@"title": @"已有备份", @"rows": backupRows}];
    }
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    
    if (row[@"action"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
        cell.textLabel.text = row[@"title"];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        NSInteger colorType = [row[@"color"] integerValue];
        if (colorType == 2) {
            cell.textLabel.textColor = [UIColor redColor];
        } else {
            cell.textLabel.textColor = self.view.tintColor;
        }
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCell" forIndexPath:indexPath];
        cell.textLabel.text = row[@"title"];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.detailTextLabel.text = row[@"value"] ?: @"";
        cell.accessoryType = row[@"backupFile"] ? UITableViewCellAccessoryDetailButton : UITableViewCellAccessoryNone;
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    NSString *action = row[@"action"];
    if (!action) return;
    
    if ([action isEqualToString:@"backup"]) {
        [self performBackup];
    } else if ([action isEqualToString:@"restore"]) {
        [self performRestore];
    } else if ([action isEqualToString:@"wipe"]) {
        [self performWipe];
    }
}

#pragma mark - 备份/恢复/抹除

- (void)performBackup {
    [self showProgress:@"正在备份..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = [self.backupManager backupApp:self.appItem error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgress];
            if (success) {
                [self showAlert:@"成功" message:@"备份完成"];
                [self refreshBackups];
                [self buildSections];
                [self.tableView reloadData];
            } else {
                [self showAlert:@"失败" message:error.localizedDescription ?: @"备份失败"];
            }
        });
    });
}

- (void)performRestore {
    if (self.backups.count == 0) {
        [self showAlert:@"提示" message:@"没有可恢复的备份"];
        return;
    }
    if (self.backups.count == 1) {
        [self restoreBackup:self.backups[0]];
        return;
    }
    // 多备份选择
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"选择备份" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *b in self.backups) {
        [ac addAction:[UIAlertAction actionWithTitle:b[@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self restoreBackup:b];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)restoreBackup:(NSDictionary *)backupInfo {
    [self showProgress:@"正在恢复..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = [self.backupManager restoreApp:self.appItem fromBackup:backupInfo error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgress];
            if (success) {
                [self showAlert:@"成功" message:@"恢复完成"];
            } else {
                [self showAlert:@"失败" message:error.localizedDescription ?: @"恢复失败"];
            }
        });
    });
}

- (void)performWipe {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"确认抹除"
                                                                message:@"此操作将删除该应用的所有数据，不可恢复！"
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"确认抹除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self showProgress:@"正在抹除..."];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            BOOL success = [self.backupManager wipeApp:self.appItem error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgress];
                if (success) {
                    [self showAlert:@"成功" message:@"数据已抹除"];
                } else {
                    [self showAlert:@"失败" message:error.localizedDescription ?: @"抹除失败"];
                }
            });
        });
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - 工具

- (void)showProgress:(NSString *)text {
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:text message:nil preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];
}

- (void)hideProgress {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
