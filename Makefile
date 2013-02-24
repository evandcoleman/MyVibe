export THEOS_DEVICE_IP=192.168.0.95
export ARCHS = armv7
export GO_EASY_ON_ME=0
export TARGET=iphone:clang:latest:6.0

include theos/makefiles/common.mk

TWEAK_NAME = MyVibe
MyVibe_FILES = Tweak.xm
MyVibe_FRAMEWORKS = UIKit CoreMotion
MyVibe_PRIVATE_FRAMEWORKS = BulletinBoard

SUBPROJECTS = settings
include $(THEOS_MAKE_PATH)/tweak.mk

include $(FW_MAKEDIR)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"