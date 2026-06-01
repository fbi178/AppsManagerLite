#import "BackupManager.h"
#import "ApplicationItem.h"
#import "BackupFileManager.h"
#import "IDFVManager.h"

#define KCACCESS_PATH @"/var/tmp/kcaccess"
#define KCACCESS_ENT_PATH @"/var/tmp/kcaccess_ent.plist"

@implementation BackupManager

+ (instancetype)sharedInstance {
    static BackupManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

#pragma mark - 备份

- (BOOL)backupApp:(ApplicationItem *)item error:(NSError **)error {
    if (!item.dataContainerPath || item.dataContainerPath.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"BackupError" code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"无法获取应用容器路径"}];
        return NO;
    }
    
    NSString *backupId = [self generateBackupId];
    NSString *backupPath = [[BackupFileManager sharedInstance] backupFilePathForBundleId:item.bundleId backupId:backupId];
    NSString *workDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"bk_%@", backupId]];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:workDir error:nil];
    [fm createDirectoryAtPath:workDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    @try {
        // 1. 复制 Documents 目录
        NSString *docPath = [item.dataContainerPath stringByAppendingPathComponent:@"Documents"];
        if ([fm fileExistsAtPath:docPath]) {
            [self copyPath:docPath toPath:[workDir stringByAppendingPathComponent:@"Documents"]];
        }
        
        // 2. 复制 Library 目录（排除一些系统缓存）
        NSString *libPath = [item.dataContainerPath stringByAppendingPathComponent:@"Library"];
        if ([fm fileExistsAtPath:libPath]) {
            NSString *libDest = [workDir stringByAppendingPathComponent:@"Library"];
            [self copyPath:libPath toPath:libDest];
            // 清理不需要的缓存
            [fm removeItemAtPath:[libDest stringByAppendingPathComponent:@"Caches/com.apple.UserNotifications"] error:nil];
        }
        
        // 3. 复制 App Groups
        int groupIdx = 0;
        for (NSString *groupPath in item.groupContainerPaths) {
            if ([fm fileExistsAtPath:groupPath]) {
                NSString *groupDir = [workDir stringByAppendingPathComponent:[NSString stringWithFormat:@"AppGroup_%d", groupIdx++]];
                [self copyPath:groupPath toPath:groupDir];
            }
        }
        
        // 4. 保存 App Info.plist
        NSString *appBundlePath = [self bundlePathForBundleId:item.bundleId];
        if (appBundlePath) {
            NSString *srcInfo = [appBundlePath stringByAppendingPathComponent:@"Info.plist"];
            if ([fm fileExistsAtPath:srcInfo]) {
                [fm copyItemAtPath:srcInfo toPath:[workDir stringByAppendingPathComponent:@"Info.plist"] error:nil];
            }
        }
        
        // 5. 备份钥匙串
        [self backupKeychainForBundleId:item.bundleId toPath:workDir];
        
        // 6. 备份 IDFV/IDFA（如果启用）
        [[IDFVManager sharedInstance] backupIDFVForApp:item.bundleId toPath:workDir];
        [[IDFVManager sharedInstance] backupIDFAForApp:item.bundleId toPath:workDir];
        
        // 7. 构建元数据
        NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
        metadata[@"backupId"] = backupId;
        metadata[@"bundleId"] = item.bundleId;
        metadata[@"appName"] = item.appName;
        metadata[@"version"] = item.version;
        metadata[@"date"] = [self currentDateString];
        metadata[@"deviceName"] = [[UIDevice currentDevice] name];
        metadata[@"systemVersion"] = [[UIDevice currentDevice] systemVersion];
        
        // 记录 IDFV/IDFA 到元数据
        NSString *idfv = [IDFVManager readCurrentIDFV];
        NSString *idfa = [IDFVManager readCurrentIDFA];
        if (idfv) metadata[@"idfv_backup"] = idfv;
        if (idfa) metadata[@"idfa_backup"] = idfa;
        
        // 8. 打包为 .adbk
        BackupFileManager *bfm = [BackupFileManager sharedInstance];
        BOOL success = [bfm createBackupFileAtPath:backupPath
                                      fromDataPath:workDir
                                     keychainFiles:@[]
                                          metadata:metadata
                                             error:error];
        
        // 9. 更新备份列表
        if (success) {
            NSMutableArray *list = [[bfm loadBackupListForBundleId:item.bundleId] mutableCopy] ?: [NSMutableArray array];
            [list addObject:metadata];
            [bfm saveBackupList:list forBundleId:item.bundleId];
        }
        
        [fm removeItemAtPath:workDir error:nil];
        return success;
    }
    @catch (NSException *exception) {
        [fm removeItemAtPath:workDir error:nil];
        if (error) *error = [NSError errorWithDomain:@"BackupError" code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"备份异常"}];
        return NO;
    }
}

#pragma mark - 恢复

- (BOOL)restoreApp:(ApplicationItem *)item fromBackup:(NSDictionary *)backupInfo error:(NSError **)error {
    if (!item.dataContainerPath || item.dataContainerPath.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"RestoreError" code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"无法获取应用容器路径"}];
        return NO;
    }
    
    NSString *backupId = backupInfo[@"backupId"];
    NSString *backupPath = [[BackupFileManager sharedInstance] backupFilePathForBundleId:item.bundleId backupId:backupId];
    NSString *workDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"rst_%u", arc4random()]];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    @try {
        // 1. 解压备份文件
        if (![[BackupFileManager sharedInstance] extractBackupFileAtPath:backupPath toTempDir:workDir error:error]) {
            return NO;
        }
        
        // 2. 恢复 Documents
        NSString *docSrc = [workDir stringByAppendingPathComponent:@"Documents"];
        NSString *docDst = [item.dataContainerPath stringByAppendingPathComponent:@"Documents"];
        if ([fm fileExistsAtPath:docSrc]) {
            [fm removeItemAtPath:docDst error:nil];
            [fm copyItemAtPath:docSrc toPath:docDst error:nil];
        }
        
        // 3. 恢复 Library
        NSString *libSrc = [workDir stringByAppendingPathComponent:@"Library"];
        NSString *libDst = [item.dataContainerPath stringByAppendingPathComponent:@"Library"];
        if ([fm fileExistsAtPath:libSrc]) {
            [fm removeItemAtPath:libDst error:nil];
            [fm copyItemAtPath:libSrc toPath:libDst error:nil];
        }
        
        // 4. 恢复 App Groups
        for (int i = 0; i < item.groupContainerPaths.count; i++) {
            NSString *groupSrc = [workDir stringByAppendingPathComponent:[NSString stringWithFormat:@"AppGroup_%d", i]];
            if ([fm fileExistsAtPath:groupSrc]) {
                [fm removeItemAtPath:item.groupContainerPaths[i] error:nil];
                [fm copyItemAtPath:groupSrc toPath:item.groupContainerPaths[i] error:nil];
            }
        }
        
        // 5. 检查 IDFV/IDFA 备份并恢复
        if ([[IDFVManager sharedInstance] hasIDFVBackupInPath:workDir]) {
            [[IDFVManager sharedInstance] restoreIDFVFromPath:workDir toContainer:item.dataContainerPath];
        }
        if ([[IDFVManager sharedInstance] hasIDFABackupInPath:workDir]) {
            [[IDFVManager sharedInstance] restoreIDFAFromPath:workDir toContainer:item.dataContainerPath];
        }
        
        // 6. 恢复钥匙串
        NSString *kcFile = [workDir stringByAppendingPathComponent:@"kcaccess.xml"];
        if ([fm fileExistsAtPath:kcFile]) {
            [self restoreKeychainFromPath:kcFile forBundleId:item.bundleId];
        }
        
        [fm removeItemAtPath:workDir error:nil];
        return YES;
    }
    @catch (NSException *exception) {
        [fm removeItemAtPath:workDir error:nil];
        if (error) *error = [NSError errorWithDomain:@"RestoreError" code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"恢复异常"}];
        return NO;
    }
}

#pragma mark - 抹除

- (BOOL)wipeApp:(ApplicationItem *)item error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 清空 Documents
    NSString *docPath = [item.dataContainerPath stringByAppendingPathComponent:@"Documents"];
    if ([fm fileExistsAtPath:docPath]) {
        [fm removeItemAtPath:docPath error:nil];
        [fm createDirectoryAtPath:docPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    // 清空 Library（保留系统必要的）
    NSString *libPath = [item.dataContainerPath stringByAppendingPathComponent:@"Library"];
    if ([fm fileExistsAtPath:libPath]) {
        NSArray *libContents = [fm contentsOfDirectoryAtPath:libPath error:nil];
        for (NSString *name in libContents) {
            if (![name isEqualToString:@"Caches"] && ![name isEqualToString:@"Preferences"]) {
                [fm removeItemAtPath:[libPath stringByAppendingPathComponent:name] error:nil];
            }
        }
        // 清空 Caches 和 Preferences
        [fm removeItemAtPath:[libPath stringByAppendingPathComponent:@"Caches"] error:nil];
    }
    
    // 抹除本app的备份记录
    NSString *backupDir = [[[BackupFileManager sharedInstance] backupDirForBundleId:item.bundleId] stringByDeletingLastPathComponent];
    [fm removeItemAtPath:backupDir error:nil];
    
    return YES;
}

#pragma mark - 查询备份

- (NSArray *)backupsForApp:(NSString *)bundleId {
    return [[BackupFileManager sharedInstance] loadBackupListForBundleId:bundleId];
}

#pragma mark - 钥匙串 (占位，需要 kcaccess 工具)

// 运行系统命令（TrollStore 环境可用，使用 posix_spawn）
static int runShellCmd(const char *cmd) {
    pid_t pid;
    char *argv[] = {"/bin/sh", "-c", (char *)cmd, NULL};
    int ret = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
    if (ret == 0) {
        int status;
        waitpid(pid, &status, 0);
        return WEXITSTATUS(status);
    }
    return -1;
}

- (BOOL)backupKeychainForBundleId:(NSString *)bundleId toPath:(NSString *)outputPath {
    NSString *kcPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"kcaccess"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:kcPath]) {
        NSString *xmlPath = [outputPath stringByAppendingPathComponent:@"kcaccess.xml"];
        NSString *cmd = [NSString stringWithFormat:@"\"%@\" backup \"%@\" \"%@\"", kcPath, bundleId, xmlPath];
        runShellCmd([cmd UTF8String]);
    }
    return YES;
}

- (BOOL)restoreKeychainFromPath:(NSString *)backupPath forBundleId:(NSString *)bundleId {
    NSString *kcPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"kcaccess"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:kcPath]) {
        NSString *cmd = [NSString stringWithFormat:@"\"%@\" restore \"%@\" \"%@\"", kcPath, bundleId, backupPath];
        runShellCmd([cmd UTF8String]);
    }
    return YES;
}

#pragma mark - 辅助方法

- (NSString *)generateBackupId {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyyMMddHHmmss";
    return [fmt stringFromDate:[NSDate date]];
}

- (NSString *)currentDateString {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [fmt stringFromDate:[NSDate date]];
}

- (void)copyPath:(NSString *)src toPath:(NSString *)dst {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:dst error:nil];
    [fm copyItemAtPath:src toPath:dst error:nil];
}

- (NSString *)bundlePathForBundleId:(NSString *)bundleId {
    // 通过 LSApplicationWorkspace 获取
    id workspace = [NSClassFromString(@"LSApplicationWorkspace") performSelector:@selector(defaultWorkspace)];
    NSArray *proxies = [workspace performSelector:@selector(allInstalledApplications)];
    for (id proxy in proxies) {
        NSString *bid = [proxy performSelector:@selector(applicationIdentifier)];
        if ([bid isEqualToString:bundleId]) {
            NSURL *url = [proxy performSelector:@selector(bundleURL)];
            return url.path;
        }
    }
    return nil;
}

@end
