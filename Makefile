include $(THEOS)/makefiles/common.mk

ARCHS = arm64
TARGET = iphone:14.5:14.0

APPLICATION_NAME = BoBoManagerLite
BoBoManagerLite_FILES = \
    main.m \
    AppDelegate.m \
    AppListController.m \
    AppTableViewCell.m \
    ApplicationItem.m \
    AppDetailController.m \
    BackupManager.m \
    BackupFileManager.m \
    BackupsListController.m \
    IDFVManager.m \
    SettingsController.m \
    PlistEditorController.m \
    ResignController.m

BoBoManagerLite_FRAMEWORKS = \
    UIKit Foundation MobileCoreServices Security \
    CoreGraphics QuartzCore MessageUI AdSupport

BoBoManagerLite_PRIVATE_FRAMEWORKS = \
    MobileCoreServices \
    FrontBoardServices

BoBoManagerLite_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 BoBoManagerLite 2>/dev/null; uicache -p /Applications/BoBoManagerLite.app"
