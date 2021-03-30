.PHONY: all install log connect forward clean

SECRET ?= $(shell php -r 'include "../config.php"; echo $$secret;')
SERVER ?= $(shell php -r 'include "../config.php"; echo $$server;')
PREFIX ?= .product

ifeq ($(shell uname),Darwin)

BUNDLE_ID   = $(shell PlistBuddy -c 'Print CFBundleIdentifier' resources/Info.plist | tr -d '"')
DESTDIR    ?= /Users/Shared/Library/CoreServices
ENDPOINT   ?= $(shell scutil --get LocalHostName)
SIGNING_ID ?= $(shell id -F)
USERNAME   ?= $(shell id -nu)

# used to fill in launchd.plist
export BUNDLE_ID DESTDIR ENDPOINT SECRET SERVER USERNAME

TOPLEVEL = \
	$(PREFIX)/SSHProxy.bundle/Contents/Info.plist
BINARIES = \
	$(PREFIX)/SSHProxy.bundle/Contents/MacOS/ssh-connect \
	$(PREFIX)/SSHProxy.bundle/Contents/MacOS/ssh-forward
RESOURCES = \
	$(PREFIX)/SSHProxy.bundle/Contents/Resources/ssh_config \
	$(PREFIX)/SSHProxy.bundle/Contents/Resources/$(BUNDLE_ID).plist

.INTERMEDIATE: resources/$(BUNDLE_ID).plist

all: $(TOPLEVEL) $(BINARIES) $(RESOURCES)

install:
	$(MAKE) PREFIX=$(DESTDIR) all
	-codesign -f --deep -s "$(SIGNING_ID)" -i $(BUNDLE_ID) -o kill,hard,runtime $(DESTDIR)/SSHProxy.bundle

resources/$(BUNDLE_ID).plist: resources/launchd.plist resources/Info.plist $(wildcard ../config.php)
	eval "`printf "cat << EOF\n$$(cat $<)\nEOF"`" > $@

log:
	@log stream --predicate '(process BEGINSWITH "ssh") OR (eventMessage CONTAINS "ssh")'

else

ENDPOINT ?= $(shell hostname)

BINARIES = \
	$(PREFIX)/bin/ssh-connect \
	$(PREFIX)/bin/ssh-forward
RESOURCES = \
	$(PREFIX)/share/ssh-proxy/ssh_config

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

.build/release/ssh-connect .build/release/ssh-forward: .build/release/ssh-%: %/main.swift $(wildcard common/*)
	rm -f $@
	swift build --product $(@F) --configuration release
	$(MAKE) .check

# check downloaded packages against known-good versions
.check: $(wildcard .build/checkouts/*)
ifneq ($(shell which nix),)
	@for pkg in $? ; do \
		test -d $$pkg/.git && mv $$pkg/.git .build/ ; \
		hash=$$(nix hash-path $$pkg) ; \
		if ! grep -qF "$$hash" ../flake.lock ; then \
			echo "$$pkg is not a known-good version" ; \
			exit 1 ; \
		fi ; \
		test -d .build/.git && mv .build/.git $$pkg/ ; \
	done ; \
	touch $@
endif

connect forward: all
	$(call dirname,$(BINARIES))/ssh-$@ --endpoint $(ENDPOINT) --key $(SECRET) --url $(SERVER)

clean:
	rm -rf .build .check .swiftpm $(PREFIX) Package.resolved
