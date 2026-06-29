TWEAK_NAME := KayokoCore

KayokoCore_USE_MODULES := 0

KayokoCore_FILES += KayokoCore.m
KayokoCore_FILES += KayokoCoreLogos.xm
KayokoCore_FILES += $(wildcard ../../Manager/*.m Views/*.m ../../Utils/*.m)

KayokoCore_CFLAGS += -fobjc-arc
KayokoCore_CFLAGS += -I../../Manager
KayokoCore_CFLAGS += -I../../Preferences
KayokoCore_CFLAGS += -I../../Utils

KayokoCore_FRAMEWORKS += AudioToolbox
KayokoCore_FRAMEWORKS += AVFoundation
KayokoCore_FRAMEWORKS += CoreGraphics
KayokoCore_FRAMEWORKS += QuartzCore
KayokoCore_FRAMEWORKS += UIKit

KayokoCore_LIBRARIES += sqlite3
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
KayokoCore_LIBRARIES += roothide
endif

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/tweak.mk
