TWEAK_NAME := KayokoHelper

KayokoHelper_USE_MODULES := 0

KayokoHelper_FILES += KayokoHelper.m
KayokoHelper_FILES += KayokoHelperConfiguration.m
KayokoHelper_FILES += KayokoHelperProcessContext.m
KayokoHelper_FILES += KayokoHelperHookInstaller.m
KayokoHelper_FILES += KayokoHelperLocalization.m
KayokoHelper_FILES += KayokoHelperRuntime.m
KayokoHelper_FILES += KayokoPredictionBarHooks.m
KayokoHelper_FILES += KayokoCalloutMenuHooks.m
KayokoHelper_FILES += KayokoInputSwitcherHooks.mm
KayokoHelper_FILES += KayokoDictationHooks.m
KayokoHelper_FILES += KayokoSwipeUpGestureRecognizer.m
KayokoHelper_FILES += KayokoSwipeUpHooks.m

KayokoHelper_CFLAGS += -fobjc-arc
KayokoHelper_CFLAGS += -I../../Preferences

KayokoHelper_FRAMEWORKS += CoreGraphics
KayokoHelper_FRAMEWORKS += QuartzCore
KayokoHelper_FRAMEWORKS += UIKit
KayokoHelper_FRAMEWORKS += AudioToolbox

KayokoHelper_LIBRARIES += substrate
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
KayokoHelper_LIBRARIES += roothide
endif

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/tweak.mk
