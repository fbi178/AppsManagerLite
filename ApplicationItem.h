#import <UIKit/UIKit.h>

@interface ApplicationItem : NSObject

@property (nonatomic, copy) NSString *bundleId;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, copy) NSString *dataContainerPath;
@property (nonatomic, strong) NSArray *groupContainerPaths;
@property (nonatomic, assign) BOOL isSystemApp;
@property (nonatomic, assign) BOOL isUserApp;

- (instancetype)initWithBundleId:(NSString *)bundleId
                         appName:(NSString *)appName
                         version:(NSString *)version
                            icon:(UIImage *)icon
               dataContainerPath:(NSString *)dataContainerPath
              groupContainerPaths:(NSArray *)groupContainerPaths
                      isSystemApp:(BOOL)isSystemApp;

+ (NSArray<ApplicationItem *> *)allInstalledApps;
+ (NSString *)dataContainerForBundleId:(NSString *)bundleId;

@end
