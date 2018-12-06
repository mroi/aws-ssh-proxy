DESTDIR ?= /Users/Shared/Library/CoreServices
SIGNING_ID ?= $(shell id -F)
BUNDLE_ID = $(shell PlistBuddy -c 'Print CFBundleIdentifier' Info.plist)
SWIFTFLAGS := -target x86_64-apple-macos10.13 -import-objc-header sandbox.h $(SWIFTFLAGS)
CFLAGS := -O2 -Wall -mmacosx-version-min=10.13 $(CFLAGS)

export DESTDIR BUNDLE_ID

.PHONY: all clean cleanall

all: $(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources

$(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources: \
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/SSHProxy \
	$(DESTDIR)/SSHProxy.bundle/Contents/Info.plist \
	$(DESTDIR)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist
	codesign -f -s "$(SIGNING_ID)" -i $(BUNDLE_ID) -o kill,hard,runtime $<

$(DESTDIR)/SSHProxy.bundle/Contents/Info.plist: Info.plist
	mkdir -p $(@D) && cp $< $@

$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/SSHProxy: .build/release/SSHProxy
	mkdir -p $(@D) && cp $< $@

$(DESTDIR)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist: launchd.plist Info.plist ../config.php
	mkdir -p $(@D)
	eval "`echo "cat << EOF\n$$(<$<)\nEOF"`" > $@

.build/release/SSHProxy: .build/release/SSHProxy.build/sandbox.o $(wildcard *.swift)
	swift build -c release --static-swift-stdlib \
		$(foreach flag,$(SWIFTFLAGS),-Xswiftc $(flag)) -Xlinker $<

.build/release/SSHProxy.build/sandbox.o: sandbox.c sandbox.h
	mkdir -p $(@D) && $(CC) $(CFLAGS) $(LDFLAGS) -c -o $@ $<

clean:
	rm -rf .build

cleanall: clean
	rm -rf $(DESTDIR)/SSHProxy.bundle
