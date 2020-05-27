.PHONY: all connect forward log clean cleanall

SECRET ?= $(shell php -r 'include "../config.php"; echo $$secret;')
SERVER ?= $(shell php -r 'include "../config.php"; echo $$server;')

ifeq ($(shell uname),Darwin)

BUNDLE_ID   = $(shell PlistBuddy -c 'Print CFBundleIdentifier' resources/Info.plist)
DESTDIR    ?= /Users/Shared/Library/CoreServices
ENDPOINT   ?= $(shell scutil --get LocalHostName)
SIGNING_ID ?= $(shell id -F)
USERNAME   ?= $(shell id -nu)

# used to fill in launchd.plist
export BUNDLE_ID DESTDIR ENDPOINT SECRET SERVER USERNAME

TOPLEVEL = \
	$(DESTDIR)/SSHProxy.bundle/Contents/Info.plist
BINARIES = \
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/ssh-connect \
	$(DESTDIR)/SSHProxy.bundle/Contents/MacOS/ssh-forward
RESOURCES = \
	$(DESTDIR)/SSHProxy.bundle/Contents/Resources/ssh_config

all: $(TOPLEVEL) $(BINARIES) $(RESOURCES) \
	$(DESTDIR)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist \
	$(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources

$(DESTDIR)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist: resources/launchd.plist resources/Info.plist ../config.php
	mkdir -p $(@D)
	eval "`echo "cat << EOF\n$$(cat $<)\nEOF"`" > $@

$(DESTDIR)/SSHProxy.bundle/Contents/_CodeSignature/CodeResources: $(TOPLEVEL) $(BINARIES) $(RESOURCES)
	codesign -f --deep -s "$(SIGNING_ID)" -i $(BUNDLE_ID) -o kill,hard,runtime $(DESTDIR)/SSHProxy.bundle

log:
	@log stream --predicate '(process BEGINSWITH "ssh") OR (eventMessage CONTAINS "ssh")'

else

DESTDIR  ?= .install
ENDPOINT ?= $(shell hostname)

BINARIES = \
	$(DESTDIR)/bin/ssh-connect \
	$(DESTDIR)/bin/ssh-forward
RESOURCES = \
	$(DESTDIR)/share/ssh-proxy/ssh_config

all: $(BINARIES) $(RESOURCES)

endif

# extract the directory portion from a list of files (sort is to deduplicate)
dirname = $(sort $(patsubst %/,%,$(dir $(1))))

$(TOPLEVEL): $(call dirname,$(TOPLEVEL))/%: resources/%
	mkdir -p $(@D) && cp $< $@ && chmod 644 $@

$(BINARIES): $(call dirname,$(BINARIES))/%: .build/release/%
	mkdir -p $(@D) && cp $< $@ && chmod 755 $@

$(RESOURCES): $(call dirname,$(RESOURCES))/%: resources/%
	mkdir -p $(@D) && cp $< $@ && chmod 644 $@

.build/release/ssh-connect .build/release/ssh-forward: .build/release/ssh-%: %/main.swift $(wildcard *.c *.h *.swift)
	rm -f $@
	swift build --product $(@F) --configuration release

connect forward: all
	$(call dirname,$(BINARIES))/ssh-$@ --endpoint $(ENDPOINT) --key $(SECRET) --url $(SERVER)

clean:
	rm -rf .build .install

cleanall: clean
	rm -rf $(DESTDIR)/SSHProxy.bundle
