// 啵啵-ManagerLite IDFV/IDFA 恢复 Hook 脚本
// 使用方式: frida -U -f <目标App> -l idfv_hook.js
// 或者 attach 到已运行App: frida -U <App名> -l idfv_hook.js

// 配置：IDFV/IDFA 备份文件路径（由 啵啵-ManagerLite 恢复时写入）
// 默认在目标App的 Documents/.bobo_idfv 和 Documents/.bobo_idfa

if (ObjC.available) {
    // === Hook IDFV ===
    var UIDevice = ObjC.classes.UIDevice;
    if (UIDevice) {
        // Hook identifierForVendor 方法
        var hookIDFV = function() {
            var className = "UIDevice";
            var selName = "identifierForVendor";
            
            // 使用 Memory.alloc 分配一块内存保存 hook 后的返回值
            var idfvPath = ObjC.classes.NSHomeDirectory() + "/Documents/.bobo_idfv";
            var fileManager = ObjC.classes.NSFileManager.defaultManager();
            
            Interceptor.attach(UIDevice[selName].implementation, {
                onLeave: function(retval) {
                    // 检查是否有 IDFV 备份文件
                    var exists = fileManager.fileExistsAtPath_(idfvPath);
                    if (exists) {
                        var backupIDFV = ObjC.classes.NSString.stringWithContentsOfFile_encoding_error_(idfvPath, 4, NULL);
                        if (backupIDFV && backupIDFV.length() > 0) {
                            console.log("[IDFV Hook] 返回备份IDFV: " + backupIDFV.toString());
                            // 创建 NSUUID 对象并返回
                            var uuid = ObjC.classes.NSUUID.alloc().initWithUUIDString_(backupIDFV);
                            if (uuid) {
                                retval.replace(uuid.autorelease());
                            }
                        }
                    } else {
                        console.log("[IDFV Hook] 无备份IDFV文件，返回原始值");
                    }
                }
            });
        };
        hookIDFV();
        console.log("[✓] IDFV Hook 已安装");
    } else {
        console.log("[✗] UIDevice 类不可用");
    }
    
    // === Hook IDFA ===
    var ASIdentifierManager = ObjC.classes.ASIdentifierManager;
    if (ASIdentifierManager) {
        var idfaPath = ObjC.classes.NSHomeDirectory() + "/Documents/.bobo_idfa";
        var fileManager2 = ObjC.classes.NSFileManager.defaultManager();
        
        Interceptor.attach(ASIdentifierManager.sharedManager().advertisingIdentifier.implementation, {
            onLeave: function(retval) {
                var exists = fileManager2.fileExistsAtPath_(idfaPath);
                if (exists) {
                    var backupIDFA = ObjC.classes.NSString.stringWithContentsOfFile_encoding_error_(idfaPath, 4, NULL);
                    if (backupIDFA && backupIDFA.length() > 0) {
                        console.log("[IDFA Hook] 返回备份IDFA: " + backupIDFA.toString());
                        var uuid = ObjC.classes.NSUUID.alloc().initWithUUIDString_(backupIDFA);
                        if (uuid) {
                            retval.replace(uuid.autorelease());
                        }
                    }
                }
            }
        });
        console.log("[✓] IDFA Hook 已安装");
    } else {
        console.log("[✗] ASIdentifierManager 类不可用（IDFA hook 跳过）");
    }
    
    console.log("");
    console.log("=== 啵啵-ManagerLite IDFV/IDFA Hook ===");
    console.log("IDFV 文件: " + ObjC.classes.NSHomeDirectory() + "/Documents/.bobo_idfv");
    console.log("IDFA 文件: " + ObjC.classes.NSHomeDirectory() + "/Documents/.bobo_idfa");
    console.log("使用方法: 先用 啵啵-ManagerLite 恢复备份，再运行此脚本");
} else {
    console.log("[✗] ObjC Runtime 不可用");
}
