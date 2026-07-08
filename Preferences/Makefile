BUNDLE_NAME += KayokoPreferences

KayokoPreferences_USE_MODULES := 0

KayokoPreferences_FILES += $(wildcard Controllers/*.m Cells/*.m Utilities/*.m)
KayokoPreferences_FILES += $(wildcard ../Shared/Tags/*.m)
KayokoPreferences_FILES += $(wildcard ../Shared/Purchases/*.m)

KayokoPreferences_CFLAGS += -fobjc-arc
KayokoPreferences_CFLAGS += -I.
KayokoPreferences_CFLAGS += -I../Preferences
KayokoPreferences_CFLAGS += -IControllers
KayokoPreferences_CFLAGS += -ICells
KayokoPreferences_CFLAGS += -IUtilities
KayokoPreferences_CFLAGS += -I../Shared/Tags
KayokoPreferences_CFLAGS += -I../Shared/Purchases

KayokoPreferences_FRAMEWORKS += CoreGraphics
KayokoPreferences_FRAMEWORKS += QuartzCore
KayokoPreferences_FRAMEWORKS += Security
KayokoPreferences_FRAMEWORKS += UIKit
KayokoPreferences_PRIVATE_FRAMEWORKS += FrontBoardServices
KayokoPreferences_PRIVATE_FRAMEWORKS += Preferences
KayokoPreferences_PRIVATE_FRAMEWORKS += SpringBoardServices

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
KayokoPreferences_LIBRARIES += roothide
endif

KayokoPreferences_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk
