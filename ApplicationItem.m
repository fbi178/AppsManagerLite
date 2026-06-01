#import "ApplicationItem.h"
#import <objc/runtime.h>
#import <dlfcn.h>

@implementation ApplicationItem

- (instancetype)initWithBundleId:(NSString *)bundleId
                         appName:(NSString *)appName
                         version:(NSString *)version
                            icon:(UIImage *)icon
               dataContainerPath:(NSString *)dataContainerPath
              groupContainerPaths:(NSArray *)groupContainerPaths
                      isSystemApp:(BOOL)isSystemApp {
    self = [super init];
    if (self) {
        _bundleId = bundleId ?: @"";
        _appName = appName ?: bundleId;
        _version = version ?: @"";
        _icon = icon;
        _dataContainerPath = dataContainerPath ?: @"";
        _groupContainerPaths = groupContainerPaths ?: @[];
        _isSystemApp = isSystemApp;
        _isUserApp = !isSystemApp;
    }
    return self;
}

#pragma mark - 获取所有已安装应用

+ (NSArray<ApplicationItem *> *)allInstalledApps {
    NSMutableArray *result = [NSMutableArray array];
    
    @try {
        // 使用 LSApplicationWorkspace 获取已安装应用列表
        Class LSAppWorkspace = objc_getClass("LSApplicationWorkspace");
        if (LSAppWorkspace) {
            id workspace = [LSAppWorkspace performSelector:@selector(defaultWorkspace)];
            if (workspace) {
                NSArray *proxies = [workspace performSelector:@selector(allInstalledApplications)];
                for (id proxy in proxies) {
                    @autoreleasepool {
                        NSString *bundleId = [proxy performSelector:@selector(applicationIdentifier)];
                        NSString *appName = [proxy performSelector:@selector(localizedName)];
            NSString *version = [proxy performSelector:@selector(bundleVersion)];
            NSString *shortVersion = [proxy performSelector:@selector(shortVersionString)];
            
            if (!bundleId) continue;
            
            // 获取图标
            UIImage *icon = [self iconForProxy:proxy];
            
            // 获取数据容器路径
            NSString *dataPath = [self dataContainerForBundleId:bundleId];
            
            // 获取 App Groups
            NSArray *groupPaths = [self groupContainersForBundleId:bundleId];
            
            BOOL isSystem = [proxy performSelector:@selector(isSystemApplication)];
            
            ApplicationItem *item = [[ApplicationItem alloc] initWithBundleId:bundleId
                                                                      appName:appName ?: bundleId
                                                                      version:shortVersion ?: (version ?: @"")
                                                                         icon:icon
                                                            dataContainerPath:dataPath ?: @""
                                                           groupContainerPaths:groupPaths
                                                                   isSystemApp:isSystem];
            [result addObject:item];
                    }
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"LSApplicationWorkspace failed: %@", e.reason);
    }
    
    // 如果 API 方式没拿到结果，用文件系统扫描
    if (result.count == 0) {
        [result addObjectsFromArray:[self allAppsViaFilesystem]];
    }
    
    [result sortUsingComparator:^NSComparisonResult(ApplicationItem *a, ApplicationItem *b) {
        return [a.appName localizedCompare:b.appName];
    }];
    
    return result;
}

// 文件系统扫描（TrollStore 兼容）
+ (NSArray<ApplicationItem *> *)allAppsViaFilesystem {
    NSMutableArray *result = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *appsDir = @"/var/containers/Bundle/Application";
    NSArray *uuids = [fm contentsOfDirectoryAtPath:appsDir error:nil];
    for (NSString *uuid in uuids) {
        NSString *appPath = [appsDir stringByAppendingPathComponent:uuid];
        NSArray *apps = [fm contentsOfDirectoryAtPath:appPath error:nil];
        for (NSString *name in apps) {
            if ([name hasSuffix:@".app"]) {
                NSString *bundlePath = [appPath stringByAppendingPathComponent:name];
                NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                NSString *bundleId = info[@"CFBundleIdentifier"];
                NSString *appName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: name;
                NSString *version = info[@"CFBundleShortVersionString"] ?: @"";
                if (bundleId) {
                    ApplicationItem *item = [[ApplicationItem alloc] initWithBundleId:bundleId
                                                                              appName:appName
                                                                              version:version
                                                                                 icon:nil
                                                                    dataContainerPath:@""
                                                                   groupContainerPaths:@[]
                                                                           isSystemApp:NO];
                    [result addObject:item];
                }
            }
        }
    }
    return result;
}

+ (NSArray<ApplicationItem *> *)allAppsViaMobileInstallation {
    NSMutableArray *result = [NSMutableArray array];
    
    void *handle = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation", RTLD_LAZY);
    if (!handle) return result;
    
    id (*MobileInstallationLookup)(NSDictionary *) = dlsym(handle, "MobileInstallationLookup");
    if (!MobileInstallationLookup) {
        dlclose(handle);
        return result;
    }
    
    NSDictionary *options = @{@"ApplicationType": @"User"};
    NSDictionary *apps = MobileInstallationLookup(options);
    
    [apps enumerateKeysAndObjectsUsingBlock:^(NSString *bundleId, NSDictionary *info, BOOL *stop) {
        NSString *appName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: bundleId;
        NSString *version = info[@"CFBundleShortVersionString"] ?: info[@"CFBundleVersion"] ?: @"";
        NSString *dataPath = info[@"Container"];
        NSString *iconPath = info[@"IconFile"];
        
        UIImage *icon = nil;
        if (iconPath) {
            icon = [UIImage imageWithContentsOfFile:iconPath];
        }
        
        NSArray *groupPaths = @[];
        NSDictionary *groupInfo = info[@"ApplicationGroupIdentifiers"];
        if ([groupInfo isKindOfClass:[NSDictionary class]]) {
            // 简化处理
        }
        
        ApplicationItem *item = [[ApplicationItem alloc] initWithBundleId:bundleId
                                                                  appName:appName
                                                                  version:version
                                                                     icon:icon
                                                        dataContainerPath:dataPath ?: @""
                                                       groupContainerPaths:groupPaths
                                                               isSystemApp:NO];
        [result addObject:item];
    }];
    
    dlclose(handle);
    
    [result sortUsingComparator:^NSComparisonResult(ApplicationItem *a, ApplicationItem *b) {
        return [a.appName localizedCompare:b.appName];
    }];
    
    return result;
}

#pragma mark - 私有辅助方法

+ (UIImage *)iconForProxy:(id)proxy {
    // 尝试多种方式获取图标
    UIImage *icon = nil;
    
    // 方式1: 通过 LSApplicationProxy 获取
    SEL iconSel = NSSelectorFromString(@"iconDataForVariant:");
    if ([proxy respondsToSelector:iconSel]) {
        NSData *iconData = [proxy performSelector:iconSel withObject:@(2)]; // 2 = 60pt
        if (iconData) {
            icon = [UIImage imageWithData:iconData];
        }
    }
    
    // 方式2: 从文件系统读取
    if (!icon) {
        NSString *bundlePath = [proxy performSelector:@selector(bundleURL)];
        if (bundlePath) {
            NSString *iconPath = [bundlePath stringByAppendingPathComponent:@"AppIcon60x60@2x.png"];
            icon = [UIImage imageWithContentsOfFile:iconPath];
            if (!icon) {
                iconPath = [bundlePath stringByAppendingPathComponent:@"AppIcon.appiconset/AppIcon60x60@2x.png"];
                icon = [UIImage imageWithContentsOfFile:iconPath];
            }
        }
    }
    
    return icon ?: [self defaultAppIcon];
}

+ (UIImage *)defaultAppIcon {
    static UIImage *defaultIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultIcon = [UIImage imageNamed:@"noicon"];
    });
    return defaultIcon;
}

+ (NSString *)dataContainerForBundleId:(NSString *)bundleId {
    // 通过 MobileContainerManager 获取数据容器路径
    Class MCMContainer = objc_getClass("MCMAppDataContainer");
    if (MCMContainer) {
        id container = [MCMContainer performSelector:@selector(containerWithIdentifier:) withObject:bundleId];
        if (container) {
            NSURL *url = [container performSelector:@selector(url)];
            return url.path;
        }
    }
    
    // 备选: 直接扫描容器目录
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

+ (NSArray *)groupContainersForBundleId:(NSString *)bundleId {
    // 获取 App Groups 容器路径
    // 通过 groupContainerURLs 获取
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *groupInfo = [fm containerURLForSecurityApplicationGroupIdentifier:@""];
    // 简化: 返回空数组，后续完善
    return @[];
}

@end
