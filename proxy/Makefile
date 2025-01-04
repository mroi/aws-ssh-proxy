.PHONY: all install log connect clean

API_URL ?= $(shell php -r 'include "../config.php"; echo $$apiUrl;')
API_KEY ?= $(shell php -r 'include "../config.php"; echo $$apiKey;')
PREFIX  ?= .product
CONFIG  ?= release
ARCHS   ?= x86_64 arm64

ifeq ($(IN_NIX_SHELL),)
ifneq ($(shell which nix),)
# use Nix package manager
SHELL = nix develop --quiet --no-update-lock-file --no-warn-dirty .. --command /bin/sh
endif
endif

ifeq ($(shell uname),Darwin)

BUNDLE_ID     = $(shell PlistBuddy -c 'Print CFBundleIdentifier' resources/Info.plist | tr -d '"')
DESTDIR      ?= /Users/Shared/Library/CoreServices
LOCAL_ID     ?= $(shell scutil --get LocalHostName)
SIGNING_NAME ?= $(shell id -F)

TOPLEVEL = \
	$(PREFIX)/SSHProxy.bundle/Contents/Info.plist
BINARIES = \
	$(PREFIX)/SSHProxy.bundle/Contents/MacOS/ssh-connect \

all: $(TOPLEVEL) $(BINARIES) $(RESOURCES)

install:
	$(MAKE) PREFIX=$(DESTDIR) all
	-codesign -f --deep -s "$(SIGNING_NAME)" -i $(BUNDLE_ID) -o kill,hard,runtime $(DESTDIR)/SSHProxy.bundle

log:
	@log stream --predicate '(process BEGINSWITH "ssh") OR (eventMessage CONTAINS "ssh")'

else

LOCAL_ID ?= $(shell hostname)

BINARIES = \
	$(PREFIX)/libexec/ssh-connect \

all: $(BINARIES) $(RESOURCES)

install:
	$(MAKE) PREFIX=$(DESTDIR) all

endif

# extract the directory portion from a list of files (sort is to deduplicate)
dirname = $(sort $(patsubst %/,%,$(dir $(1))))

$(TOPLEVEL): $(call dirname,$(TOPLEVEL))/%: resources/%
	mkdir -p $(@D) && cp $< $@ && chmod 644 $@

$(BINARIES): $(call dirname,$(BINARIES))/%: .build/$(CONFIG)/%
	mkdir -p $(@D) && cp $< $@ && chmod 755 $@

$(RESOURCES): $(call dirname,$(RESOURCES))/%: resources/%
	mkdir -p $(@D) && cp $< $@ && chmod 644 $@

.build/$(CONFIG)/ssh-connect: .build/$(CONFIG)/ssh-%: %/main.swift $(wildcard common/*)
	rm -f $@
	swift build $(foreach arch,$(ARCHS),--arch $(arch)) --product $(@F) --configuration $(CONFIG)
	$(MAKE) .check

# check downloaded packages against known-good versions
.check: $(wildcard .build/checkouts/*)
ifneq ($(shell which nix),)
	@for pkg in $? ; do \
		test -d $$pkg/.git && mv $$pkg/.git .build/ ; \
		hash=$$(nix hash path $$pkg) ; \
		test -d .build/.git && mv .build/.git $$pkg/ ; \
		if ! grep -qF "$$hash" ../flake.nix ; then \
			echo "$$pkg is not a known-good version" ; \
			exit 1 ; \
		fi ; \
	done ; \
	touch $@
endif

connect: all
	$(call dirname,$(BINARIES))/ssh-$@ --id $(LOCAL_ID) --api-url $(API_URL) --api-key $(API_KEY)

clean:
	rm -rf .build .check .swiftpm $(PREFIX) Package.resolved
