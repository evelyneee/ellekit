.PHONY: all

VERSION := $(shell git describe --tags --always | sed 's/-/~/' | sed 's/-/\./g' | sed 's/\.g/\./g' | sed 's/^v//g')

COMMON_OPTIONS = CODE_SIGNING_ALLOWED="NO" CODE_SIGNING_REQUIRED="NO" CODE_SIGN_IDENTITY="" -configuration $(CONFIGURATION)

ifneq ($(RELEASE),)
CONFIGURATION = Release
DEB_VERSION = $(VERSION)
else
CONFIGURATION = Debug
DEB_VERSION = $(VERSION)+debug
endif

ifneq ($(MAC),)
$(error macOS is not supported yet)
COMMON_OPTIONS += -destination 'generic/platform=macOS'
else
COMMON_OPTIONS += -destination 'generic/platform=iOS'
endif

ifneq ($(ROOTLESS),)
INSTALL_PREFIX = /var/jb
ARCHITECTURE = iphoneos-arm64
else
INSTALL_PREFIX = 
ARCHITECTURE = iphoneos-arm
endif

ifneq ($(MAC),)
PRODUCTS_DIR = build/$(CONFIGURATION)-macosx
else
PRODUCTS_DIR = build/$(CONFIGURATION)-iphoneos
endif

STAGE_DIR = work/stage
INSTALL_ROOT = $(STAGE_DIR)/$(INSTALL_PREFIX)

# TODO: maybe split each scheme into its own target?

all: deb

clean:
	xcodebuild -scheme ellekit $(COMMON_OPTIONS) clean
	xcodebuild -scheme injector $(COMMON_OPTIONS) clean
	xcodebuild -scheme launchd $(COMMON_OPTIONS) clean
	xcodebuild -scheme loader $(COMMON_OPTIONS) clean
	xcodebuild -scheme safemode-ui $(COMMON_OPTIONS) clean

build-ios:
	xcodebuild -scheme ellekit $(COMMON_OPTIONS)
	xcodebuild -scheme injector $(COMMON_OPTIONS)
	xcodebuild -scheme launchd $(COMMON_OPTIONS)
	xcodebuild -scheme loader $(COMMON_OPTIONS)
	xcodebuild -scheme safemode-ui $(COMMON_OPTIONS)

build-macos:
	# TODO
	$(error macOS is not supported yet)

deb-ios: build-ios
	rm -rf work
	mkdir -p $(STAGE_DIR)

	install -Dm644 $(PRODUCTS_DIR)/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libellekit.dylib
	install -Dm644 $(PRODUCTS_DIR)/libinjector.dylib $(INSTALL_ROOT)/usr/lib/ellekit/libinjector.dylib
	install -Dm644 $(PRODUCTS_DIR)/pspawn.dylib $(INSTALL_ROOT)/usr/lib/ellekit/pspawn.dylib
	install -Dm644 $(PRODUCTS_DIR)/libsafemode-ui.dylib $(INSTALL_ROOT)/usr/lib/ellekit/MobileSafety.dylib
	install -Dm755 $(PRODUCTS_DIR)/loader $(INSTALL_ROOT)/usr/libexec/ellekit/loader

	find $(INSTALL_ROOT)/usr/lib -type f -exec ldid -S {} \;
	ldid -S./loader/taskforpid.xml $(INSTALL_ROOT)/usr/libexec/ellekit/loader
	
	ln -s $(INSTALL_PREFIX)/usr/lib/ellekit/libinjector.dylib $(INSTALL_ROOT)/usr/lib/TweakLoader.dylib
	ln -s $(INSTALL_PREFIX)/usr/lib/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libsubstrate.dylib
	ln -s $(INSTALL_PREFIX)/usr/lib/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libhooker.dylib

	mkdir -p $(INSTALL_ROOT)/etc/rc.d
	ln -s ${INSTALL_PREFIX}/usr/libexec/ellekit/loader $(INSTALL_ROOT)/etc/rc.d/ellekit-loader

	mkdir -p $(INSTALL_ROOT)/usr/lib/TweakInject

	mkdir -p $(INSTALL_ROOT)/Library/Frameworks/CydiaSubstrate.framework
	ln -s ${INSTALL_PREFIX}/usr/lib/libellekit.dylib $(INSTALL_ROOT)/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate
	mkdir -p $(INSTALL_ROOT)/Library/MobileSubstrate
	ln -s ${INSTALL_PREFIX}/usr/lib/TweakInject $(INSTALL_ROOT)/Library/MobileSubstrate/DynamicLibraries

	mkdir -p $(STAGE_DIR)/DEBIAN
	sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" packaging/control >$(STAGE_DIR)/DEBIAN/control

	fakeroot -s work/.fakeroot -- chown -hR 0:0 $(STAGE_DIR)
	mkdir -p packages || true
	fakeroot -i work/.fakeroot -s work/.fakeroot -- dpkg-deb -Zzstd --root-owner-group -b $(STAGE_DIR) packages/ellekit_$(DEB_VERSION)_$(ARCHITECTURE).deb
	
	rm -rf work

deb-macos:
	# TODO
	$(error macOS is not supported yet)

ifneq ($(MAC),)
deb: deb-macos
else
deb: deb-ios
endif
