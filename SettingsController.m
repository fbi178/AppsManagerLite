#import "SettingsController.h"
#import "IDFVManager.h"
#import "BackupFileManager.h"

@interface SettingsController ()
@property (nonatomic, strong) NSMutableArray *sections;
@end

@implementation SettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SwitchCell"];
    [self buildSections];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildSections];
    [self.tableView reloadData];
}

- (void)buildSections {
    self.sections = [NSMutableArray array];
    
    // Section: IDFV/IDFA 设置
    NSMutableArray *idfvRows = [NSMutableArray array];
    [idfvRows addObject:@{
        @"title": @"备份 IDFV",
        @"desc": @"备份时保存设备 Vendor Identifier，恢复时可还原",
        @"key": @"idfv",
        @"type": @"switch"
    }];
    [idfvRows addObject:@{
        @"title": @"备份 IDFA",
        @"desc": @"备份时保存广告标识符(ATTrackingManager)，恢复时可还原",
        @"key": @"idfa",
        @"type": @"switch"
    }];
    
    // 显示当前设备 IDFV
    NSString *currentIDFV = [IDFVManager readCurrentIDFV] ?: @"无法获取";
    NSString *currentIDFA = [IDFVManager readCurrentIDFA] ?: @"未授权或不可用";
    [idfvRows addObject:@{
        @"title": @"本机 IDFV",
        @"value": currentIDFV,
        @"type": @"info"
    }];
    [idfvRows addObject:@{
        @"title": @"本机 IDFA",
        @"value": currentIDFA,
        @"type": @"info"
    }];
    
    [self.sections addObject:@{@"title": @"设备标识备份", @"rows": idfvRows}];
    
    // Section: 关于
    NSMutableArray *aboutRows = [NSMutableArray array];
    [aboutRows addObject:@{@"title": @"版本", @"value": @"1.0.0", @"type": @"info"}];
    [aboutRows addObject:@{@"title": @"作者", @"value": @"bobo", @"type": @"info"}];
    [aboutRows addObject:@{@"title": @"支持 iOS", @"value": @"14.0 - 16.7", @"type": @"info"}];
    
    // 显示备份占用空间
    NSString *sizeStr = [self backupSizeString];
    [aboutRows addObject:@{@"title": @"备份占用", @"value": sizeStr, @"type": @"info"}];
    
    [self.sections addObject:@{@"title": @"关于", @"rows": aboutRows}];
}

- (NSString *)backupSizeString {
    NSString *rootPath = [[BackupFileManager sharedInstance] backupRootPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:rootPath]) return @"0 B";
    
    NSUInteger totalSize = 0;
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:rootPath];
    for (NSString *file in enumerator) {
        NSDictionary *attrs = [fm attributesOfItemAtPath:[rootPath stringByAppendingPathComponent:file] error:nil];
        totalSize += [attrs fileSize];
    }
    
    if (totalSize < 1024) return [NSString stringWithFormat:@"%lu B", (unsigned long)totalSize];
    if (totalSize < 1024*1024) return [NSString stringWithFormat:@"%.1f KB", totalSize/1024.0];
    return [NSString stringWithFormat:@"%.1f MB", totalSize/(1024.0*1024.0)];
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

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"恢复备份时自动检测是否有 IDFV/IDFA 备份，有则自动恢复设备标识。需配合 Frida 脚本使用。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    NSString *type = row[@"type"];
    
    if ([type isEqualToString:@"switch"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SwitchCell" forIndexPath:indexPath];
        cell.textLabel.text = row[@"title"];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.textColor = [UIColor blackColor];
        
        UISwitch *sw = [[UISwitch alloc] init];
        NSString *key = row[@"key"];
        if ([key isEqualToString:@"idfv"]) {
            sw.on = [IDFVManager sharedInstance].backupIDFVEnabled;
            [sw addTarget:self action:@selector(idfvSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([key isEqualToString:@"idfa"]) {
            sw.on = [IDFVManager sharedInstance].backupIDFAEnabled;
            [sw addTarget:self action:@selector(idfaSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
        cell.textLabel.text = row[@"title"];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.detailTextLabel.text = row[@"value"] ?: @"";
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
}

#pragma mark - 开关

- (void)idfvSwitchChanged:(UISwitch *)sender {
    [IDFVManager sharedInstance].backupIDFVEnabled = sender.on;
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"backupIDFVEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)idfaSwitchChanged:(UISwitch *)sender {
    [IDFVManager sharedInstance].backupIDFAEnabled = sender.on;
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"backupIDFAEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
