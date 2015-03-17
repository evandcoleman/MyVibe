export THEOS_DEVICE_IP=10.0.1.72
export GO_EASY_ON_ME=1
export TARGET=iphone:clang:8.1:6.0
export ARCHS = arm64 armv7
export THEOS=/opt/theos

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyVibe
MyVibe_FILES = Tweak.xm
MyVibe_FRAMEWORKS = UIKit CoreMotion
MyVibe_PRIVATE_FRAMEWORKS = BulletinBoard

SUBPROJECTS = settings myvibetoggle
include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += myvibepreferenceshooks
include $(FW_MAKEDIR)/aggregate.mk

after-install::
	install.exec "killall -9 backboardd"
