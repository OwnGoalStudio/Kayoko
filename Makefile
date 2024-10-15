export ARCHS = arm64 arm64e
export TARGET = iphone:clang:16.5:14.0

INSTALL_TARGET_PROCESSES := SpringBoard Preferences

SUBPROJECTS += Tweak/Core
SUBPROJECTS += Tweak/Helper
SUBPROJECTS += Daemon
SUBPROJECTS += Preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
stage::
	plutil -replace Program -string $(THEOS_PACKAGE_INSTALL_PREFIX)/usr/libexec/kayokod $(THEOS_STAGING_DIR)/Library/LaunchDaemons/codes.aurora.kayokod.plist
endif
