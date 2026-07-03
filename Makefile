export PACKAGE_VERSION := 4.0.4
export ARCHS := arm64 arm64e
export TARGET := iphone:clang:16.5:14.0

INSTALL_TARGET_PROCESSES := backboardd druid pasted

SUBPROJECTS += Tweak/Core
SUBPROJECTS += Tweak/Helper
SUBPROJECTS += Preferences
SUBPROJECTS += Updater

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
