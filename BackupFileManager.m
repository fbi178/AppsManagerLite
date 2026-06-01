#import "BackupFileManager.h"
#import <zlib.h>
#import <spawn.h>
#import <sys/wait.h>
#import <stdlib.h>

#define kBackupRoot @"/var/mobile/Library/BoBoManager"

// 运行系统命令
static int runCmd(const char *cmd) {
    pid_t pid;
    char *argv[] = {"/bin/sh", "-c", (char *)cmd, NULL};
    extern char **environ;
    int ret = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
    if (ret == 0) { int status; waitpid(pid, &status, 0); return WEXITSTATUS(status); }
    return -1;
}
#define kBackupListFile @"Backups.plist"

@implementation BackupFileManager

+ (instancetype)sharedInstance {
    static BackupFileManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance ensureDirectories];
    });
    return instance;
}

- (void)ensureDirectories {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *root = [self backupRootPath];
    if (![fm fileExistsAtPath:root]) {
        [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (NSString *)backupRootPath {
    return kBackupRoot;
}

- (NSString *)backupDirForBundleId:(NSString *)bundleId {
    NSString *dir = [[self backupRootPath] stringByAppendingPathComponent:bundleId];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

- (NSString *)backupFilePathForBundleId:(NSString *)bundleId backupId:(NSString *)backupId {
    return [[self backupDirForBundleId:bundleId] stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@.adbk", backupId]];
}

#pragma mark - ZIP 打包 (使用系统 zip 命令)

- (BOOL)createBackupFileAtPath:(NSString *)destPath
                  fromDataPath:(NSString *)dataPath
                 keychainFiles:(NSArray *)keychainFiles
                      metadata:(NSDictionary *)metadata
                         error:(NSError **)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *workDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"backup_%u", arc4random()]];
    
    // 1. 创建工作目录
    [fm removeItemAtPath:workDir error:nil];
    [fm createDirectoryAtPath:workDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    // 2. 复制数据到工作目录
    NSString *dataCopy = [workDir stringByAppendingPathComponent:@"AppData"];
    if ([fm fileExistsAtPath:dataPath]) {
        [fm copyItemAtPath:dataPath toPath:dataCopy error:nil];
    }
    
    // 3. 保存元数据
    [metadata writeToFile:[workDir stringByAppendingPathComponent:@"Binfo.plist"] atomically:YES];
    
    // 4. 保存钥匙串文件
    for (NSString *kcFile in keychainFiles) {
        NSString *dest = [workDir stringByAppendingPathComponent:[kcFile lastPathComponent]];
        if ([fm fileExistsAtPath:kcFile]) {
            [fm copyItemAtPath:kcFile toPath:dest error:nil];
        }
    }
    
    // 5. 打包为 ZIP
    NSString *zipCmd = [NSString stringWithFormat:@"/usr/bin/zip -r -q \"%@\" .", destPath];
    int ret = runCmd([zipCmd UTF8String]);
    
    // 6. 清理
    [fm removeItemAtPath:workDir error:nil];
    
    if (ret != 0 && error) {
        *error = [NSError errorWithDomain:@"BackupError" code:ret userInfo:@{NSLocalizedDescriptionKey: @"打包备份文件失败"}];
        return NO;
    }
    return YES;
}

#pragma mark - ZIP 解包

- (BOOL)extractBackupFileAtPath:(NSString *)backupPath
                     toTempDir:(NSString *)tempDir
                         error:(NSError **)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *unzipCmd = [NSString stringWithFormat:@"/usr/bin/unzip -o -q \"%@\" -d \"%@\"", backupPath, tempDir];
    int ret = runCmd([unzipCmd UTF8String]);
    
    if (ret != 0 && error) {
        *error = [NSError errorWithDomain:@"BackupError" code:ret userInfo:@{NSLocalizedDescriptionKey: @"解压备份文件失败"}];
        return NO;
    }
    return YES;
}

#pragma mark - 备份列表管理

- (NSString *)backupListPathForBundleId:(NSString *)bundleId {
    return [[self backupDirForBundleId:bundleId] stringByAppendingPathComponent:kBackupListFile];
}

- (NSArray *)loadBackupListForBundleId:(NSString *)bundleId {
    NSString *path = [self backupListPathForBundleId:bundleId];
    return [NSArray arrayWithContentsOfFile:path] ?: @[];
}

- (BOOL)saveBackupList:(NSArray *)list forBundleId:(NSString *)bundleId {
    NSString *path = [self backupListPathForBundleId:bundleId];
    return [list writeToFile:path atomically:YES];
}

@end
