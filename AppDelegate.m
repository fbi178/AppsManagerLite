#import "AppDelegate.h"
#import "AppListController.h"
#import "BackupsListController.h"
#import "SettingsController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    // Tab 1: 应用列表
    AppListController *appListVC = [[AppListController alloc] init];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:appListVC];
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"应用" 
                                                   image:[self imageNamed:@"app_icon"] 
                                                     tag:0];
    
    // Tab 2: 备份管理
    BackupsListController *backupsVC = [[BackupsListController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:backupsVC];
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"备份" 
                                                   image:[self imageNamed:@"backup_icon"] 
                                                     tag:1];
    
    // Tab 3: 设置
    SettingsController *settingsVC = [[SettingsController alloc] init];
    UINavigationController *nav3 = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav3.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"设置" 
                                                   image:[self imageNamed:@"settings_icon"] 
                                                     tag:2];
    
    self.tabController = [[UITabBarController alloc] init];
    self.tabController.viewControllers = @[nav1, nav2, nav3];
    self.tabController.tabBar.translucent = NO;
    
    if (@available(iOS 15.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        self.tabController.tabBar.standardAppearance = appearance;
        self.tabController.tabBar.scrollEdgeAppearance = appearance;
    }
    
    self.window.rootViewController = self.tabController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (UIImage *)imageNamed:(NSString *)name {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
    return path ? [UIImage imageWithContentsOfFile:path] : nil;
}

@end
