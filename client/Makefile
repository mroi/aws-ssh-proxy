DESTDIR ?= /Users/Shared/Library/CoreServices
SIGNING_ID ?= $(shell id -F)
BUNDLE_ID = $(shell PlistBuddy -c 'Print CFBundleIdentifier' Info.plist)

.PHONY: all clean cleanall

all: $(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources

$(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources: \
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/SSHProxy \
	$(DESTDIR)/SSHProxy.bundle/Contents/Info.plist \
	entitlements.plist
	codesign -f -s "$(SIGNING_ID)" -i $(BUNDLE_ID) -o kill,hard,runtime --entitlements entitlements.plist $<

$(DESTDIR)/SSHProxy.bundle/Contents/Info.plist: Info.plist
	mkdir -p $(@D) && cp $< $@

$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/SSHProxy: .build/release/SSHProxy
	mkdir -p $(@D) && cp $< $@

.build/release/SSHProxy: $(wildcard *.swift)
	swift build -c release --static-swift-stdlib

clean:
	rm -rf .build

cleanall: clean
	rm -rf $(DESTDIR)/SSHProxy.bundle
