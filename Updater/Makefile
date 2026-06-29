ARCHS := arm64
TOOL_NAME := kayoko_updater

kayoko_updater_USE_MODULES := 0

kayoko_updater_FILES += main.m
kayoko_updater_FILES += KayokoPostinstallUpdater.m
kayoko_updater_FILES += ../Manager/KayokoHistoryStore.m
kayoko_updater_FILES += ../Manager/KayokoHistoryMigrator.m
kayoko_updater_FILES += ../Manager/PasteboardItem.m

kayoko_updater_CFLAGS += -fobjc-arc
kayoko_updater_CFLAGS += -I../Manager
kayoko_updater_CFLAGS += -I../Preferences

kayoko_updater_LIBRARIES += sqlite3
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
kayoko_updater_LIBRARIES += roothide
endif

kayoko_updater_INSTALL_PATH := /usr/local/libexec
kayoko_updater_CODESIGN_FLAGS += -Splatformize.entitlements

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tool.mk
