BUNDLE_ID = $(shell PlistBuddy -c 'Print CFBundleIdentifier' Info.plist)
DESTDIR ?= /Users/Shared/Library/CoreServices
ENDPOINT ?= $(shell scutil --get LocalHostName)
KEY ?= $(shell php -r 'include "../config.php"; echo $$secret;')
URL ?= $(shell php -r 'include "../config.php"; echo $$url;')
USERNAME ?= $(shell id -nu)

# used to fill in launchd.plist
export BUNDLE_ID DESTDIR ENDPOINT KEY URL USERNAME

SIGNING_ID ?= $(shell id -F)
SWIFTFLAGS := -target x86_64-apple-macos10.13 -import-objc-header sandbox.h $(SWIFTFLAGS)
CFLAGS := -O2 -Wall -mmacosx-version-min=10.13 $(CFLAGS)

.PHONY: all run log clean cleanall

all: $(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources

$(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources: \
	$(DESTDIR)/SSHProxy.bundle/Contents/Info.plist \
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/ssh-forward \
	$(DESTDIR)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist
	codesign -f --deep -s "$(SIGNING_ID)" -i $(BUNDLE_ID) -o kill,hard,runtime $(DESTDIR)/SSHProxy.bundle

$(DESTDIR)/SSHProxy.bundle/Contents/Info.plist: Info.plist
	mkdir -p $(@D) && cp $< $@

$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/ssh-forward: .build/release/ssh-forward
	mkdir -p $(@D) && cp $< $@

$(DESTDIR)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist: launchd.plist Info.plist ../config.php
	mkdir -p $(@D)
	eval "`echo "cat << EOF\n$$(<$<)\nEOF"`" > $@

.build/release/ssh-forward: .build/sandbox.o $(wildcard forward/*.swift)
	rm -f $@
	swift build --product $(@F) --configuration release --static-swift-stdlib \
		$(foreach flag,$(SWIFTFLAGS),-Xswiftc $(flag)) -Xlinker $<

.build/sandbox.o: sandbox.c sandbox.h
	mkdir -p $(@D) && $(CC) $(CFLAGS) $(LDFLAGS) -c -o $@ $<

run: all
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/ssh-forward \
		--endpoint $(ENDPOINT) --key $(KEY) --url $(URL)

log:
	@log stream --predicate '(process == "ssh-forward") or (eventMessage contains "ssh-forward")'

clean:
	rm -rf .build

cleanall: clean
	rm -rf $(DESTDIR)/SSHProxy.bundle
