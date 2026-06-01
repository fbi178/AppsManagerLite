#import "IDFVManager.h"
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

#define IDFV_FILE @".bobo_idfv"
#define IDFA_FILE @".bobo_idfa"

@implementation IDFVManager

+ (instancetype)sharedInstance {
    static IDFVManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        // 默认开启
        instance.backupIDFVEnabled = YES;
        instance.backupIDFAEnabled = NO; // IDFA 默认关闭，需用户主动开启
    });
    return instance;
}

#pragma mark - 备份

- (void)backupIDFVForApp:(NSString *)bundleId toPath:(NSString *)workDir {
    if (!self.backupIDFVEnabled) return;
    
    NSString *idfv = [IDFVManager readCurrentIDFV];
    if (idfv) {
        NSString *filePath = [workDir stringByAppendingPathComponent:IDFV_FILE];
        [idfv writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)backupIDFAForApp:(NSString *)bundleId toPath:(NSString *)workDir {
    if (!self.backupIDFAEnabled) return;
    
    NSString *idfa = [IDFVManager readCurrentIDFA];
    if (idfa) {
        NSString *filePath = [workDir stringByAppendingPathComponent:IDFA_FILE];
        [idfa writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

#pragma mark - 检查

- (BOOL)hasIDFVBackupInPath:(NSString *)workDir {
    NSString *filePath = [workDir stringByAppendingPathComponent:IDFV_FILE];
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

- (BOOL)hasIDFABackupInPath:(NSString *)workDir {
    NSString *filePath = [workDir stringByAppendingPathComponent:IDFA_FILE];
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

#pragma mark - 恢复

- (void)restoreIDFVFromPath:(NSString *)workDir toContainer:(NSString *)containerPath {
    NSString *srcFile = [workDir stringByAppendingPathComponent:IDFV_FILE];
    NSString *dstFile = [[containerPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:IDFV_FILE];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    // 确保 Documents 目录存在
    NSString *docDir = [containerPath stringByAppendingPathComponent:@"Documents"];
    if (![fm fileExistsAtPath:docDir]) {
        [fm createDirectoryAtPath:docDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    // 复制 IDFV 文件到目标 App 的 Documents 目录
    [fm removeItemAtPath:dstFile error:nil];
    [fm copyItemAtPath:srcFile toPath:dstFile error:nil];
}

- (void)restoreIDFAFromPath:(NSString *)workDir toContainer:(NSString *)containerPath {
    NSString *srcFile = [workDir stringByAppendingPathComponent:IDFA_FILE];
    NSString *dstFile = [[containerPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:IDFA_FILE];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *docDir = [containerPath stringByAppendingPathComponent:@"Documents"];
    if (![fm fileExistsAtPath:docDir]) {
        [fm createDirectoryAtPath:docDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    [fm removeItemAtPath:dstFile error:nil];
    [fm copyItemAtPath:srcFile toPath:dstFile error:nil];
}

#pragma mark - 读取已保存的

+ (NSString *)readIDFVForBundleId:(NSString *)bundleId {
    // 从目标 App 的容器中读取 IDFV 备份文件
    NSString *containerPath = [self dataContainerForBundleId:bundleId];
    if (!containerPath) return nil;
    
    NSString *filePath = [[containerPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:IDFV_FILE];
    return [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
}

+ (NSString *)readIDFAForBundleId:(NSString *)bundleId {
    NSString *containerPath = [self dataContainerForBundleId:bundleId];
    if (!containerPath) return nil;
    
    NSString *filePath = [[containerPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:IDFA_FILE];
    return [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark - 读取当前设备

+ (NSString *)readCurrentIDFV {
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

+ (NSString *)readCurrentIDFA {
    if (NSClassFromString(@"ASIdentifierManager")) {
        if ([[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled]) {
            return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
        }
    }
    return nil;
}

#pragma mark - 辅助

+ (NSString *)dataContainerForBundleId:(NSString *)bundleId {
    Class MCMContainer = objc_getClass("MCMAppDataContainer");
    if (MCMContainer) {
        id container = [MCMContainer performSelector:@selector(containerWithIdentifier:) withObject:bundleId];
        if (container) {
            NSURL *url = [container performSelector:@selector(url)];
            return url.path;
        }
    }
    
    // 备选: 扫描容器目录
    NSString *containersDir = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = [fm contentsOfDirectoryAtPath:containersDir error:nil];
    for (NSString *dir in dirs) {
        NSString *metaPath = [NSString stringWithFormat:@"%@/%@/.com.apple.mobile_container_manager.metadata.plist", containersDir, dir];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        if ([meta[@"MCMMetadataIdentifier"] isEqualToString:bundleId]) {
            return [containersDir stringByAppendingPathComponent:dir];
        }
    }
    return nil;
}

@end
