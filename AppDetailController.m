#import "AppDetailController.h"
#import "ApplicationItem.h"
#import "BackupManager.h"
#import "IDFVManager.h"

@implementation AppDetailController {
    BackupManager *_backupManager;
    NSArray *_backups;
}

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
    self.title = self.appItem.appName ?: @"应用详情";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    _backups = [_backupManager backupsForApp:self.appItem.bundleId];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"应用信息", @"操作", @"备份列表"][section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 3;
    return _backups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.textColor = [UIColor blackColor];
    cell.detailTextLabel.text = @"";
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    
    if (indexPath.section == 0) {
        NSArray *labels = @[@"名称", @"Bundle ID", @"版本", @"容器路径"];
        NSArray *values = @[
            self.appItem.appName ?: @"未知",
            self.appItem.bundleId ?: @"未知",
            self.appItem.version ?: @"未知",
            [self.appItem.dataContainerPath length] > 0 ? self.appItem.dataContainerPath : @"无权访问"
        ];
        cell.textLabel.text = [NSString stringWithFormat:@"%@: %@", labels[indexPath.row], values[indexPath.row]];
        cell.textLabel.font = [UIFont systemFontOfSize:12];
        cell.textLabel.numberOfLines = 0;
    }
    else if (indexPath.section == 1) {
        NSArray *actions = @[@"备份数据", @"恢复数据", @"抹除数据"];
        cell.textLabel.text = actions[indexPath.row];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = indexPath.row == 2 ? [UIColor redColor] : self.view.tintColor;
        cell.textLabel.font = [UIFont systemFontOfSize:16];
    }
    else {
        NSDictionary *b = _backups[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@ - %@", b[@"date"]?:@"", b[@"appName"]?:@""];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        if (indexPath.row == 0) [self doBackup];
        else if (indexPath.row == 1) [self doRestore];
        else [self doWipe];
    }
}

#pragma mark - Actions

- (void)doBackup {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"备份中" message:@"请稍候..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:ac animated:YES completion:nil];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *err = nil;
        BOOL ok = [_backupManager backupApp:self.appItem error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:^{
                NSString *msg = ok ? @"备份完成" : [NSString stringWithFormat:@"失败: %@", err.localizedDescription ?: @"未知错误"];
                [self showMsg:ok ? @"成功" : @"失败" msg:msg];
                if (ok) { _backups = [_backupManager backupsForApp:self.appItem.bundleId]; [self.tableView reloadData]; }
            }];
        });
    });
}

- (void)doRestore {
    if (_backups.count == 0) { [self showMsg:@"提示" msg:@"没有可恢复的备份"]; return; }
    if (_backups.count == 1) { [self restoreWithDict:_backups[0]]; return; }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"选择备份" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *b in _backups) {
        [ac addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ - %@", b[@"date"]?:@"", b[@"appName"]?:@""] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self restoreWithDict:b]; }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)restoreWithDict:(NSDictionary *)b {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"恢复中" message:@"请稍候..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:ac animated:YES completion:nil];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *err = nil;
        BOOL ok = [_backupManager restoreApp:self.appItem fromBackup:b error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:^{
                [self showMsg:ok ? @"成功" : @"失败" msg:ok ? @"恢复完成" : [NSString stringWithFormat:@"%@", err.localizedDescription ?: @"未知错误"]];
            }];
        });
    });
}

- (void)doWipe {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"确认" message:@"此操作不可恢复，确定抹除?" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"抹除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSError *err = nil;
            BOOL ok = [_backupManager wipeApp:self.appItem error:&err];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showMsg:ok ? @"完成" : @"失败" msg:ok ? @"已抹除" : err.localizedDescription ?: @"未知错误"];
            });
        });
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)showMsg:(NSString *)title msg:(NSString *)msg {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
