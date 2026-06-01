# 啵啵-ManagerLite 编译指南

## 环境要求

- Windows 10 64-bit 或 Linux
- WSL2 (Windows 用户) 或 原生终端 (Linux 用户)
- 约 3-5GB 磁盘空间

## 第一步：安装 WSL2 (Windows 用户)

```powershell
# 以管理员身份运行 PowerShell
wsl --install -d Ubuntu-22.04
# 重启后，设置用户名密码
# 进入 WSL 终端
```

## 第二步：安装 Theos

```bash
# 在 WSL/Linux 终端中执行
sudo apt update
sudo apt install git curl build-essential fakeroot libz-dev -y

# 安装 Theos
export THEOS=~/theos
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

# 下载 iOS SDK
cd $THEOS
curl -LO https://github.com/xybp888/iOS-SDKs/raw/master/iPhoneOS14.5.sdk.tar.xz
tar -xf iPhoneOS14.5.sdk.tar.xz
rm iPhoneOS14.5.sdk.tar.xz

# 验证
ls $THEOS/sdks/iPhoneOS*.sdk
```

## 第三步：编译

```bash
# 将项目目录复制到 WSL 中
# 假设源码在 Windows D:\AppsManagerLite
# 在 WSL 中执行：
cp -r /mnt/d/AppsManagerLite ~/AppsManagerLite
cd ~/AppsManagerLite

# 设置环境变量
export THEOS=~/theos

# 编译
make package

# 编译产物在 Packages/ 目录下
ls Packages/
```

## 第四步：安装到 iPhone

```bash
# 方式1：通过 SCP 传到 iPhone
scp Packages/com.bobo.ManagerLite_1.0.0_iphoneos-arm64.tipa root@设备IP:/var/mobile/Documents/

# 方式2：通过 HTTP 下载
python3 -m http.server 8080
# iPhone Safari 打开 http://WSL_IP:8080/ 下载

# 安装：在 iPhone 上用 TrollStore 打开 .tipa 文件
```

## 第五步：IDFV/IDFA 恢复（配合 Frida）

恢复备份后，需要运行 Frida 脚本让目标 App 读取备份的 IDFV/IDFA：

```bash
# 安装 Frida 到 iPhone
# Cydia/Sileo 中添加 https://build.frida.re 源，安装 frida

# 运行 Hook 脚本
frida -U -f com.目标app.bundleId -l idfv_hook.js
```

## 项目文件说明

```
AppsManagerLite/
├── Makefile                 # Theos 编译配置
├── control                  # 包信息
├── Info.plist               # App 配置
├── Entitlements.plist       # 权限声明
├── main.m                   # 入口
├── AppDelegate.m/.h         # 应用生命周期
├── MainTabController.m/.h   # Tab 切换
├── AppListController.m/.h   # 应用列表页
├── AppDetailController.m/.h # 应用详情/备份/恢复
├── AppTableViewCell.m/.h    # 应用列表 Cell
├── ApplicationItem.m/.h     # 应用数据模型
├── BackupManager.m/.h       # 备份/恢复核心逻辑
├── BackupFileManager.m/.h   # .adbk 打包/解包
├── BackupsListController.m/.h # 备份管理页
├── IDFVManager.m/.h         # IDFV/IDFA 备份恢复
├── SettingsController.m/.h  # 设置页
├── PlistEditorController.m/.h # Plist 编辑器(骨架)
├── ResignController.m/.h    # 重签名(骨架)
├── idfv_hook.js             # Frida Hook 脚本
├── kcaccess_ent.plist       # 钥匙串工具权限
└── Resources/
    └── LaunchScreen.storyboard
```

## 已知问题

1. **钥匙串**：需要从原版 Apps Manager 提取 `kcaccess` 二进制放入此项目目录
2. **Plist 编辑器**：基础骨架，待完善
3. **代码重签名**：基础骨架，待完善（需 `fastPathSign` 工具）
4. **App Groups**：容器路径获取可能有兼容性问题
