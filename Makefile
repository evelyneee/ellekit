.PHONY: all deb-ios-rootless deb-ios-rootful

ifneq ($(ONLY_TAG),)
VERSION := $(shell git describe --tags --abbrev=0 | sed 's/^v//g')
else
VERSION := $(shell git describe --tags --always | sed 's/-/|/' | sed 's/-/\./g' | sed 's/|/-/' | sed 's/\.g/\./g' | sed 's/^v//g')
endif

COMMON_OPTIONS = BUILD_DIR="build/" CODE_SIGNING_ALLOWED="NO" CODE_SIGNING_REQUIRED="NO" CODE_SIGN_IDENTITY="" -configuration $(CONFIGURATION)

ifneq ($(RELEASE),)
CONFIGURATION = Release
DEB_VERSION = $(VERSION)
else
CONFIGURATION = Debug
DEB_VERSION = $(VERSION)+debug
endif

ifneq ($(MAC),)
COMMON_OPTIONS += -destination 'generic/platform=macOS'
PRODUCTS_DIR = build/$(CONFIGURATION)
else
COMMON_OPTIONS += -destination 'generic/platform=iOS'
PRODUCTS_DIR = build/$(CONFIGURATION)-iphoneos
endif

ifneq ($(MAC),)
COMMON_OPTIONS += ARCHS="x86_64 arm64e"
endif

STAGE_DIR = work-$(ARCHITECTURE)/stage
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
	xcodebuild -scheme ellekit $(COMMON_OPTIONS)
	xcodebuild -scheme injector $(COMMON_OPTIONS)
	xcodebuild -scheme launchd $(COMMON_OPTIONS)
	# Loader currently broken on Intel
	# xcodebuild -scheme loader $(COMMON_OPTIONS)

deb-ios-rootful: ARCHITECTURE = iphoneos-arm
deb-ios-rootful: INSTALL_PREFIX = 

deb-ios-rootless: ARCHITECTURE = iphoneos-arm64
deb-ios-rootless: INSTALL_PREFIX = /var/jb

deb-ios-rootful deb-ios-rootless: build-ios
	@rm -rf work-$(ARCHITECTURE)
	@mkdir -p $(STAGE_DIR)

	@# Because BSD install does not support -D
	@mkdir -p $(INSTALL_ROOT)/usr/lib/ellekit
	@mkdir -p $(INSTALL_ROOT)/usr/libexec/ellekit

	@install -m644 $(PRODUCTS_DIR)/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libellekit.dylib
	@install -m644 $(PRODUCTS_DIR)/libinjector.dylib $(INSTALL_ROOT)/usr/lib/ellekit/libinjector.dylib
	@install -m644 $(PRODUCTS_DIR)/pspawn.dylib $(INSTALL_ROOT)/usr/lib/ellekit/pspawn.dylib
	@install -m644 $(PRODUCTS_DIR)/libsafemode-ui.dylib $(INSTALL_ROOT)/usr/lib/ellekit/MobileSafety.dylib
	@install -m755 $(PRODUCTS_DIR)/loader $(INSTALL_ROOT)/usr/libexec/ellekit/loader

	@find $(INSTALL_ROOT)/usr/lib -type f -exec ldid -S {} \;
	@ldid -S./loader/taskforpid.xml $(INSTALL_ROOT)/usr/libexec/ellekit/loader
	
	@ln -s $(INSTALL_PREFIX)/usr/lib/ellekit/libinjector.dylib $(INSTALL_ROOT)/usr/lib/TweakLoader.dylib
	@ln -s $(INSTALL_PREFIX)/usr/lib/ellekit/libinjector.dylib $(INSTALL_ROOT)/usr/lib/TweakInject.dylib
	@ln -s $(INSTALL_PREFIX)/usr/lib/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libsubstrate.dylib
	@ln -s $(INSTALL_PREFIX)/usr/lib/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libhooker.dylib
	@ln -s $(INSTALL_PREFIX)/usr/lib/libellekit.dylib $(INSTALL_ROOT)/usr/lib/libblackjack.dylib

	@mkdir -p $(INSTALL_ROOT)/etc/rc.d
	@ln -s ${INSTALL_PREFIX}/usr/libexec/ellekit/loader $(INSTALL_ROOT)/etc/rc.d/ellekit-loader

	@mkdir -p $(INSTALL_ROOT)/usr/lib/TweakInject

	@mkdir -p $(INSTALL_ROOT)/Library/Frameworks/CydiaSubstrate.framework
	@ln -s ${INSTALL_PREFIX}/usr/lib/libellekit.dylib $(INSTALL_ROOT)/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate
	@mkdir -p $(INSTALL_ROOT)/Library/MobileSubstrate
	@ln -s ${INSTALL_PREFIX}/usr/lib/TweakInject $(INSTALL_ROOT)/Library/MobileSubstrate/DynamicLibraries

	@mkdir -p $(INSTALL_ROOT)/usr/share/doc/ellekit
	@install -m644 LICENSE $(INSTALL_ROOT)/usr/share/doc/ellekit/LICENSE

	@mkdir -p $(STAGE_DIR)/DEBIAN
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" packaging/control >$(STAGE_DIR)/DEBIAN/control
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" -e "s|@INSTALL_PREFIX@|$(INSTALL_PREFIX)|g" packaging/preinst >$(STAGE_DIR)/DEBIAN/preinst
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" -e "s|@INSTALL_PREFIX@|$(INSTALL_PREFIX)|g" packaging/postinst >$(STAGE_DIR)/DEBIAN/postinst
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" -e "s|@INSTALL_PREFIX@|$(INSTALL_PREFIX)|g" packaging/postrm >$(STAGE_DIR)/DEBIAN/postrm
	@chmod 0755 $(STAGE_DIR)/DEBIAN/preinst $(STAGE_DIR)/DEBIAN/postinst $(STAGE_DIR)/DEBIAN/postrm

	@mkdir -p packages
	dpkg-deb -Zzstd --root-owner-group -b $(STAGE_DIR) packages/ellekit_$(DEB_VERSION)_$(ARCHITECTURE).deb
	
	@rm -rf work-$(ARCHITECTURE)

deb-ios: deb-ios-rootful deb-ios-rootless

deb-macos-amd64: ARCHITECTURE = darwin-amd64
deb-macos-amd64: BINARY_ARCH = x86_64

deb-macos-arm64: ARCHITECTURE = darwin-arm64
deb-macos-arm64: BINARY_ARCH = arm64e

# TODO: add .pkg support?

# Note: on a macOS Procursus installation, dpkg will try to remove /usr/local if ellekit is the only package installed there
deb-macos-amd64 deb-macos-arm64: INSTALL_PREFIX = 
deb-macos-amd64 deb-macos-arm64: build-macos
	@rm -rf work-$(ARCHITECTURE)
	@mkdir -p $(STAGE_DIR)

	@# Because BSD install does not support -D
	@mkdir -p $(INSTALL_ROOT)/usr/local/lib/ellekit
	@mkdir -p $(INSTALL_ROOT)/usr/local/libexec/ellekit
	@mkdir -p $(INSTALL_ROOT)/Library/TweakInject

	@install -m644 $(PRODUCTS_DIR)/libellekit.dylib $(INSTALL_ROOT)/usr/local/lib/libellekit.dylib
	@install -m644 $(PRODUCTS_DIR)/libinjector.dylib $(INSTALL_ROOT)/usr/local/lib/ellekit/libinjector.dylib
	@install -m644 $(PRODUCTS_DIR)/pspawn.dylib $(INSTALL_ROOT)/Library/TweakInject/pspawn.dylib
	# @install -m755 $(PRODUCTS_DIR)/loader $(INSTALL_ROOT)/usr/local/libexec/ellekit/loader

	# Instead of building twice for arm64 and x86_64, we can just use lipo to thin the binaries
	@find $(INSTALL_ROOT) -type f -exec lipo -thin $(BINARY_ARCH) {} -output {} \;

	@find $(INSTALL_ROOT)/usr/local/lib $(INSTALL_ROOT)/Library/TweakInject -type f -exec ldid -S {} \;
	# @ldid -S./loader/taskforpid.xml $(INSTALL_ROOT)/usr/local/libexec/ellekit/loader
	
	@ln -s $(INSTALL_PREFIX)/usr/local/lib/libellekit.dylib $(INSTALL_ROOT)/usr/local/lib/libsubstrate.dylib
	@ln -s $(INSTALL_PREFIX)/usr/local/lib/libellekit.dylib $(INSTALL_ROOT)/usr/local/lib/libhooker.dylib
	@ln -s $(INSTALL_PREFIX)/usr/local/lib/libellekit.dylib $(INSTALL_ROOT)/usr/local/lib/libblackjack.dylib

	# @mkdir -p $(INSTALL_ROOT)/Library/Frameworks/CydiaSubstrate.framework
	# @ln -s ${INSTALL_PREFIX}/usr/lib/libellekit.dylib $(INSTALL_ROOT)/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate
	# @mkdir -p $(INSTALL_ROOT)/Library/MobileSubstrate
	# @ln -s ${INSTALL_PREFIX}/usr/lib/TweakInject $(INSTALL_ROOT)/Library/MobileSubstrate/DynamicLibraries

	@mkdir -p $(INSTALL_ROOT)/usr/local/share/doc/ellekit
	@install -m644 LICENSE $(INSTALL_ROOT)/usr/local/share/doc/ellekit/LICENSE

	@mkdir -p $(STAGE_DIR)/DEBIAN
	@sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" packaging/control >$(STAGE_DIR)/DEBIAN/control
	# TODO: Adjust the postinst script to work with macOS
	# @sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" -e "s|@INSTALL_ROOT@|$(INSTALL_ROOT)|g" packaging/postinst >$(STAGE_DIR)/DEBIAN/postinst
	# @sed -e "s|@DEB_VERSION@|$(DEB_VERSION)|g" -e "s|@DEB_ARCH@|$(ARCHITECTURE)|g" -e "s|@INSTALL_ROOT@|$(INSTALL_ROOT)|g" packaging/postrm >$(STAGE_DIR)/DEBIAN/postrm
	# @chmod 0755 $(STAGE_DIR)/DEBIAN/postinst $(STAGE_DIR)/DEBIAN/postrm

	@mkdir -p packages
	dpkg-deb -Zzstd --root-owner-group -b $(STAGE_DIR) packages/ellekit_$(DEB_VERSION)_$(ARCHITECTURE).deb

	@rm -rf work-$(ARCHITECTURE)

deb-macos: deb-macos-amd64 deb-macos-arm64

ifneq ($(MAC),)
deb: deb-macos
else
deb: deb-ios
endif

ifneq ($(MAC),)
build: build-macos
else
build: build-ios
endif
