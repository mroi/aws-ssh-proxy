BUNDLE_ID = $(shell PlistBuddy -c 'Print CFBundleIdentifier' resources/Info.plist)
DESTDIR  ?= /Users/Shared/Library/CoreServices
ENDPOINT ?= $(shell scutil --get LocalHostName)
KEY      ?= $(shell php -r 'include "../config.php"; echo $$secret;')
URL      ?= $(shell php -r 'include "../config.php"; echo $$url;')
USERNAME ?= $(shell id -nu)

# used to fill in launchd.plist
export BUNDLE_ID DESTDIR ENDPOINT KEY URL USERNAME

SIGNING_ID ?= $(shell id -F)
SWIFTFLAGS := -target x86_64-apple-macos10.13 -import-objc-header sandbox.h $(SWIFTFLAGS)
CFLAGS     := -O2 -Wall -mmacosx-version-min=10.13 $(CFLAGS)

TOPLEVEL = \
	$(DESTDIR)/SSHProxy.bundle/Contents/Info.plist
BINARIES = \
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/ssh-connect \
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/ssh-forward
RESOURCES = \
	$(DESTDIR)/SSHProxy.bundle/Contents/Resources/ssh_config \
	$(DESTDIR)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist

.PHONY: all connect forward log xcode clean cleanall

all: $(TOPLEVEL) $(BINARIES) $(RESOURCES) $(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources

$(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources: $(TOPLEVEL) $(BINARIES) $(RESOURCES)
	codesign -f --deep -s "$(SIGNING_ID)" -i $(BUNDLE_ID) -o kill,hard,runtime $(DESTDIR)/SSHProxy.bundle

$(TOPLEVEL): $(DESTDIR)/SSHProxy.bundle/Contents/%: resources/%
	mkdir -p $(@D) && cp -p $< $@ && chmod 644 $@

$(BINARIES): $(DESTDIR)/SSHProxy.bundle/Contents/MacOS/%: .build/release/%
	mkdir -p $(@D) && cp -p $< $@ && chmod 755 $@

$(DESTDIR)/SSHProxy.bundle/Contents/Resources/%: resources/%
	mkdir -p $(@D) && cp -p $< $@ && chmod 644 $@

$(DESTDIR)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist: resources/launchd.plist resources/Info.plist ../config.php
	mkdir -p $(@D)
	eval "`echo "cat << EOF\n$$(<$<)\nEOF"`" > $@

.build/release/ssh-connect .build/release/ssh-forward: .build/release/ssh-%: .build/sandbox.o %/main.swift util.swift
	rm -f $@
	swift build --product $(@F) --configuration release --static-swift-stdlib \
		$(foreach flag,$(SWIFTFLAGS),-Xswiftc $(flag)) -Xlinker $<

.build/sandbox.o: sandbox.c sandbox.h
	mkdir -p $(@D) && $(CC) $(CFLAGS) $(LDFLAGS) -c -o $@ $<

connect forward: all
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/ssh-$@ \
		--endpoint $(ENDPOINT) --key $(KEY) --url $(URL)

log:
	@log stream --predicate '(process BEGINSWITH "ssh") OR (eventMessage CONTAINS "ssh")'

xcode:
	swift package generate-xcodeproj
	open SSHProxy.xcodeproj

clean:
	rm -rf .build SSHProxy.xcodeproj

cleanall: clean
	rm -rf $(DESTDIR)/SSHProxy.bundle
