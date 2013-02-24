export TARGET=iphone:clang:latest:6.0

include theos/makefiles/common.mk

BUNDLE_NAME = MyVibeSettings
MyVibeSettings_FILES = MyVibeSettings.mm
MyVibeSettings_INSTALL_PATH = /Library/PreferenceBundles
MyVibeSettings_FRAMEWORKS = UIKit Social Accounts
MyVibeSettings_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/MyVibeSettings.plist$(ECHO_END)
