TWEAK_NAME := KayokoCore

KayokoCore_FILES += KayokoCore.m
KayokoCore_FILES += $(wildcard ../../Manager/*.m Views/*.m ../../Utils/*.m)
KayokoCore_CFLAGS += -fobjc-arc
KayokoCore_CFLAGS += -I../../Manager
KayokoCore_CFLAGS += -I../../Preferences
KayokoCore_CFLAGS += -I../../Utils
KayokoCore_FRAMEWORKS += UIKit

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/tweak.mk
