#import <Foundation/Foundation.h>
@class ApplicationItem;

@interface BackupManager : NSObject

+ (instancetype)sharedInstance;

// 备份
- (BOOL)backupApp:(ApplicationItem *)item error:(NSError **)error;

// 恢复
- (BOOL)restoreApp:(ApplicationItem *)item fromBackup:(NSDictionary *)backupInfo error:(NSError **)error;

// 抹除
- (BOOL)wipeApp:(ApplicationItem *)item error:(NSError **)error;

// 查询备份列表
- (NSArray *)backupsForApp:(NSString *)bundleId;

// 钥匙串操作
- (BOOL)backupKeychainForBundleId:(NSString *)bundleId toPath:(NSString *)outputPath;
- (BOOL)restoreKeychainFromPath:(NSString *)backupPath forBundleId:(NSString *)bundleId;

@end
