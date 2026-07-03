BUNDLE_NAME += KayokoPreferences

KayokoPreferences_USE_MODULES := 0

KayokoPreferences_FILES += $(wildcard Controllers/*.m Cells/*.m)

KayokoPreferences_CFLAGS += -fobjc-arc
KayokoPreferences_CFLAGS += -I.
KayokoPreferences_CFLAGS += -I../Preferences

KayokoPreferences_FRAMEWORKS += CoreGraphics
KayokoPreferences_FRAMEWORKS += QuartzCore
KayokoPreferences_FRAMEWORKS += UIKit
KayokoPreferences_PRIVATE_FRAMEWORKS += Preferences

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
KayokoPreferences_LIBRARIES += roothide
endif

KayokoPreferences_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk
