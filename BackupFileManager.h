#import <Foundation/Foundation.h>

@interface BackupFileManager : NSObject

+ (instancetype)sharedInstance;

// 备份存储根目录
- (NSString *)backupRootPath;

// 备份文件完整路径
- (NSString *)backupFilePathForBundleId:(NSString *)bundleId backupId:(NSString *)backupId;

// 创建 .adbk 备份文件
- (BOOL)createBackupFileAtPath:(NSString *)destPath
                  fromDataPath:(NSString *)dataPath
                 keychainFiles:(NSArray *)keychainFiles
                      metadata:(NSDictionary *)metadata
                         error:(NSError **)error;

// 解压 .adbk 备份文件
- (BOOL)extractBackupFileAtPath:(NSString *)backupPath
                     toTempDir:(NSString *)tempDir
                         error:(NSError **)error;

// 备份列表
- (NSArray *)loadBackupListForBundleId:(NSString *)bundleId;
- (BOOL)saveBackupList:(NSArray *)list forBundleId:(NSString *)bundleId;

@end
