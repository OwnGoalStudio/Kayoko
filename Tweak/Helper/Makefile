TWEAK_NAME := KayokoHelper

KayokoHelper_USE_MODULES := 0

KayokoHelper_FILES += KayokoHelper.m
KayokoHelper_FILES += KayokoHelperRuntime.m
KayokoHelper_FILES += KayokoPredictionBarHooks.m
KayokoHelper_FILES += KayokoCalloutMenuHooks.m
KayokoHelper_FILES += KayokoInputSwitcherHooks.mm
KayokoHelper_FILES += KayokoDictationHooks.m
KayokoHelper_FILES += KayokoSwipeUpGestureRecognizer.m
KayokoHelper_FILES += KayokoSwipeUpHooks.m
KayokoHelper_FILES += KayokoMenu.m
KayokoHelper_FILES += $(wildcard ../../Manager/*.m)

KayokoHelper_CFLAGS += -fobjc-arc
KayokoHelper_CFLAGS += -I../../Headers
KayokoHelper_CFLAGS += -I../../Preferences
KayokoHelper_CFLAGS += -I../../Manager

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
KayokoHelper_LDFLAGS += -L../../Libraries/_roothide
else
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
KayokoHelper_LDFLAGS += -L../../Libraries/_rootless
else
KayokoHelper_LDFLAGS += -L../../Libraries
endif
endif

KayokoHelper_FRAMEWORKS += CoreGraphics
KayokoHelper_FRAMEWORKS += ImageIO
KayokoHelper_FRAMEWORKS += QuartzCore
KayokoHelper_FRAMEWORKS += UIKit

KayokoHelper_LIBRARIES += sandy
KayokoHelper_LIBRARIES += sqlite3
KayokoHelper_LIBRARIES += substrate
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
KayokoHelper_LIBRARIES += roothide
endif

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/tweak.mk
