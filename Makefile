.PHONY: all

VERSION := 0.3

all: deb

clean:
	xcodebuild -scheme ellekit -derivedDataPath build -destination 'generic/platform=iOS' clean
	xcodebuild -scheme injector -derivedDataPath build -destination 'generic/platform=iOS' clean
	xcodebuild -scheme launchd -derivedDataPath build -destination 'generic/platform=iOS' clean
	xcodebuild -scheme loader -derivedDataPath build -destination 'generic/platform=iOS' clean
	xcodebuild -scheme safemode-ui -derivedDataPath build -destination 'generic/platform=iOS' clean

release:
	xcodebuild -scheme ellekit -derivedDataPath build -destination 'generic/platform=iOS' -configuration Release
	xcodebuild -scheme injector -derivedDataPath build -destination 'generic/platform=iOS' -configuration Release
	xcodebuild -scheme launchd -derivedDataPath build -destination 'generic/platform=iOS' -configuration Release
	xcodebuild -scheme loader -derivedDataPath build -destination 'generic/platform=iOS' -configuration Release
	xcodebuild -scheme safemode-ui -derivedDataPath build -destination 'generic/platform=iOS' -configuration Release

debug:
	xcodebuild -scheme ellekit -derivedDataPath build -destination 'generic/platform=iOS' -configuration Debug
	xcodebuild -scheme injector -derivedDataPath build -destination 'generic/platform=iOS' -configuration Debug
	xcodebuild -scheme launchd -derivedDataPath build -destination 'generic/platform=iOS' -configuration Debug
	xcodebuild -scheme loader -derivedDataPath build -destination 'generic/platform=iOS' -configuration Debug
	xcodebuild -scheme safemode-ui -derivedDataPath build -destination 'generic/platform=iOS' -configuration Debug

control:
	( echo 'Package: ellekit'; \
      echo 'Name: ElleKit (Beta)'; \
      echo 'Version: $(VERSION)'; \
      echo 'Architecture: iphoneos-arm64'; \
      echo 'Maintainer: Procursus Team <support@procurs.us>'; \
      echo 'Conflicts: com.ex.substitute, org.coolstar.libhooker, science.xnu.substitute, mobilesubstrate'; \
      echo 'Replaces: com.ex.libsubstitute, org.coolstar.libhooker, mobilesubstrate'; \
      echo 'Provides: mobilesubstrate (= 99), org.coolstar.libhooker (= 1.6.9)'; \
      echo 'Author: Evelyn'; \
      echo 'Section: Tweak Injection'; \
      echo 'Priority: optional'; \
      echo 'Description: ElleKit tweak injection libraries and loader'; \
      echo ' Currently NO SAFE MODE INCLUDED! Install at your own risk!'; \
      echo ' ElleKit tweak injection libraries and loader. Currently in beta,'; \
      echo ' does not currently include a LaunchDaemon.'; \
      echo 'Depends: libiosexec1 (>= 1.2.2)'; \
	) > debsource/ellekit/DEBIAN/control

deb: release
	sudo tar xf debsource/ellekit.tar.zst -C debsource
	sudo chown -R $(shell id -u):$(shell id -g) debsource
	$(MAKE) control
	cp -RpP build/Build/Products/Release-iphoneos/libellekit.dylib debsource/ellekit/var/jb/usr/lib/libellekit.dylib
	ldid -S debsource/ellekit/var/jb/usr/lib/libellekit.dylib
	chmod 0644 debsource/ellekit/var/jb/usr/lib/libellekit.dylib
	cp -RpP build/Build/Products/Release-iphoneos/libinjector.dylib debsource/ellekit/var/jb/usr/lib/ellekit/libinjector.dylib
	ldid -S debsource/ellekit/var/jb/usr/lib/ellekit/libinjector.dylib
	chmod 0644 debsource/ellekit/var/jb/usr/lib/ellekit/libinjector.dylib
	cp -RpP build/Build/Products/Release-iphoneos/pspawn.dylib debsource/ellekit/var/jb/usr/lib/ellekit/pspawn.dylib
	ldid -S debsource/ellekit/var/jb/usr/lib/ellekit/pspawn.dylib
	chmod 0644 debsource/ellekit/var/jb/usr/lib/ellekit/pspawn.dylib
	cp -RpP build/Build/Products/Release-iphoneos/libsafemode-ui.dylib debsource/ellekit/var/jb/usr/lib/ellekit/MobileSafety.dylib
	ldid -S debsource/ellekit/var/jb/usr/lib/ellekit/MobileSafety.dylib
	chmod 0644 debsource/ellekit/var/jb/usr/lib/ellekit/MobileSafety.dylib
	cp -RpP build/Build/Products/Release-iphoneos/loader debsource/ellekit/var/jb/usr/libexec/ellekit/loader
	ldid -S debsource/ellekit/var/jb/usr/libexec/ellekit/loader
	chmod 0755 debsource/ellekit/var/jb/usr/libexec/ellekit/loader
	sudo chown -R 0:0 debsource/ellekit
	dpkg-deb -Zzstd -b debsource/ellekit ellekit_$(VERSION)_iphoneos-arm64.deb
	sudo rm -rf debsource/ellekit

deb_debug: debug
	sudo tar xf debsource/ellekit.tar.zst -C debsource
	sudo chown -R $(shell id -u):$(shell id -g) debsource
	$(MAKE) control
	cp -RpP build/Build/Products/Debug-iphoneos/libellekit.dylib debsource/ellekit/var/jb/usr/lib/libellekit.dylib
	ldid -S debsource/ellekit/var/jb/usr/lib/libellekit.dylib
	chmod 0644 debsource/ellekit/var/jb/usr/lib/libellekit.dylib
	cp -RpP build/Build/Products/Debug-iphoneos/libinjector.dylib debsource/ellekit/var/jb/usr/lib/ellekit/libinjector.dylib
	ldid -S debsource/ellekit/var/jb/usr/lib/ellekit/libinjector.dylib
	chmod 0644 debsource/ellekit/var/jb/usr/lib/ellekit/libinjector.dylib
	cp -RpP build/Build/Products/Debug-iphoneos/pspawn.dylib debsource/ellekit/var/jb/usr/lib/ellekit/pspawn.dylib
	ldid -S debsource/ellekit/var/jb/usr/lib/ellekit/pspawn.dylib
	chmod 0644 debsource/ellekit/var/jb/usr/lib/ellekit/pspawn.dylib
	cp -RpP build/Build/Products/Debug-iphoneos/libsafemode-ui.dylib debsource/ellekit/var/jb/usr/lib/ellekit/MobileSafety.dylib
	ldid -S debsource/ellekit/var/jb/usr/lib/ellekit/MobileSafety.dylib
	chmod 0644 debsource/ellekit/var/jb/usr/lib/ellekit/MobileSafety.dylib
	cp -RpP build/Build/Products/Debug-iphoneos/loader debsource/ellekit/var/jb/usr/libexec/ellekit/loader
	ldid -S debsource/ellekit/var/jb/usr/libexec/ellekit/loader
	chmod 0755 debsource/ellekit/var/jb/usr/libexec/ellekit/loader
	sudo chown -R 0:0 debsource/ellekit
	dpkg-deb -Zzstd -b debsource/ellekit ellekit_$(VERSION)_iphoneos-arm64.deb
	sudo rm -rf debsource/ellekit
