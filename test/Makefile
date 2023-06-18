export ARCHS = arm64 arm64e
export TARGET = iphone:latest:14.0
ADDITIONAL_OBJCFLAGS = -fobjc-exceptions
GO_EASY_ON_ME = 1
INSTALL_TARGET_PROCESSES = Snapchat
FINALPACKAGE = 1

LIBRARY_NAME = null
null_FRAMEWORKS = Foundation UIKit
null_FILES = hashmap.mm null.mm

null_LIBRARIES = substrate

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/aggregate.mk