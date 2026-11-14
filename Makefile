TARGET = iphone:clang:16.5:15.0
ARCHS = arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

TWEAK_NAME = PhantomSB
PhantomSB_FILES = payload/phantomsb_probe.mm
PhantomSB_CFLAGS = -fobjc-arc -O2
PhantomSB_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk