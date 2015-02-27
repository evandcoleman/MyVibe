include theos/makefiles/common.mk

TWEAK_NAME = MyVibePreferencesHooks
MyVibePreferencesHooks_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Preferences"
