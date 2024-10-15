TWEAK_NAME := KayokoHelper

KayokoHelper_FILES += KayokoHelper.m
KayokoHelper_FILES += KeyokoHelperLogos.xm
KayokoHelper_FILES += $(wildcard ../../Manager/*.m ../../Utils/*.m)
KayokoHelper_CFLAGS += -fobjc-arc
KayokoHelper_CFLAGS += -I../../Headers
KayokoHelper_CFLAGS += -I../../Preferences
KayokoHelper_CFLAGS += -I../../Manager
KayokoHelper_CFLAGS += -I../../Utils
KayokoHelper_LDFLAGS += -L../../Libraries
KayokoHelper_FRAMEWORKS += UIKit
KayokoHelper_LIBRARIES += sandy

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/tweak.mk
