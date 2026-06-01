#import <Foundation/Foundation.h>

@interface IDFVManager : NSObject

+ (instancetype)sharedInstance;

// 设置开关
@property (nonatomic, assign) BOOL backupIDFVEnabled;
@property (nonatomic, assign) BOOL backupIDFAEnabled;

// 备份 IDFV/IDFA 到工作目录
- (void)backupIDFVForApp:(NSString *)bundleId toPath:(NSString *)workDir;
- (void)backupIDFAForApp:(NSString *)bundleId toPath:(NSString *)workDir;

// 检查是否存在 IDFV/IDFA 备份
- (BOOL)hasIDFVBackupInPath:(NSString *)workDir;
- (BOOL)hasIDFABackupInPath:(NSString *)workDir;

// 恢复到目标容器
- (void)restoreIDFVFromPath:(NSString *)workDir toContainer:(NSString *)containerPath;
- (void)restoreIDFAFromPath:(NSString *)workDir toContainer:(NSString *)containerPath;

// 读取已保存的 IDFV/IDFA
+ (NSString *)readIDFVForBundleId:(NSString *)bundleId;
+ (NSString *)readIDFAForBundleId:(NSString *)bundleId;

// 读取当前设备的 IDFV/IDFA
+ (NSString *)readCurrentIDFV;
+ (NSString *)readCurrentIDFA;

@end
