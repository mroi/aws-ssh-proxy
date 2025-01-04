{
	description = "unison file sync to Amazon EFS storage";
	outputs = { self, nixpkgs }: let

		unison-sync = system:
			with nixpkgs.legacyPackages.${system}.extend (self: super: {
				# add swift to Xcode wrapper
				xcodeenv = super.xcodeenv // {
					composeXcodeWrapper = args: (super.xcodeenv.composeXcodeWrapper args).overrideAttrs (attrs: {
						buildCommand = attrs.buildCommand + ''
							ln -s /usr/libexec/PlistBuddy $out/bin/
							ln -s /usr/bin/xcode-select $out/bin/
							cat <<- "EOF" > $out/bin/swift
								#!/bin/sh
								exec /usr/bin/swift "$@" --disable-sandbox
							EOF
							chmod a+x $out/bin/swift
						'';
					});
				};
			});
			stdenvNoCC.mkDerivation {
				name = "unison-sync-${lib.substring 0 8 self.lastModifiedDate}";
				src = self;
				__noChroot = true;
				nativeBuildInputs =
					lib.optionals stdenvNoCC.buildPlatform.isLinux [
						clang swift swiftpm
					] ++ lib.optionals stdenvNoCC.buildPlatform.isDarwin [
						(xcodeenv.composeXcodeWrapper {})
					];
				patchPhase = let
					swift-argument-parser = fetchFromGitHub ({
						owner = "apple";
						repo = "swift-argument-parser";
						rev = "1.5.0";
						hash = "sha256-TRaJG8ikzuQQjH3ERfuYNKPty3qI3ziC/9v96pvlvRs=";
					} // lib.optionalAttrs stdenvNoCC.buildPlatform.isLinux {
						# TODO: compilation of argument parser 1.3.0 fails
						# https://github.com/NixOS/nixpkgs/pull/256956#issuecomment-1891063661
						rev = "1.2.3";
						hash = "sha256-qEJ329hqQyQVxtHScD7qPmWW9ZDf9bX+4xgpDlX0w5A=";
					});
					swift-asn1 = fetchFromGitHub {
						owner = "apple";
						repo = "swift-asn1";
						rev = "1.3.0";
						hash = "sha256-9WrDipPXevLnevsu3VEF2/W1l38vZIrXDCorpKZ6edo=";
					};
					swift-crypto = fetchFromGitHub {
						owner = "apple";
						repo = "swift-crypto";
						rev = "3.10.0";
						hash = "sha256-PfaOjxs4uLnpCYeDRBF9/KnoIhU98P8WZpnOnfizkmI=";
					};
				in ''
					ln -s ${swift-argument-parser} swift-argument-parser
					ln -s ${swift-asn1} swift-asn1
					cp -r ${swift-crypto} swift-crypto
					substituteInPlace swift-crypto/Package.swift --replace-fail 'url: "https://github.com/apple/swift-asn1.git"' 'path: "../swift-asn1"), //'
					substituteInPlace proxy/Package.swift --replace-fail 'url: "https://github.com/apple/swift-argument-parser.git"' 'path: "../swift-argument-parser"), //'
					substituteInPlace proxy/Package.swift --replace-fail 'url: "https://github.com/apple/swift-crypto.git"' 'path: "../swift-crypto"), //'
					substituteInPlace proxy/common/ssh.swift --replace-fail /usr/bin/ssh ${openssh}/bin/ssh
				'';
				dontUseSwiftpmBuild = true;
				makeFlags = [ "-C proxy" "DESTDIR=$(out)" "LOCAL_ID=" "API_URL=" "API_KEY=" "USERNAME=" ];
			};

		shell = system:
			with nixpkgs.legacyPackages.${system};
			mkShellNoCC {
				packages = [ php ] ++
					lib.optionals stdenv.isLinux [ gnumake clang swift swiftpm openssh ];
				shellHook = ''
					test -r ~/.local/config/shell/rc && . ~/.local/config/shell/rc
				'';
			};

	in {
		packages.aarch64-darwin.default = unison-sync "aarch64-darwin";
		packages.aarch64-linux.default = unison-sync "aarch64-linux";
		packages.x86_64-darwin.default = unison-sync "x86_64-darwin";
		packages.x86_64-linux.default = unison-sync "x86_64-linux";
		packages.aarch64-darwin.unison-sync = unison-sync "aarch64-darwin";
		packages.aarch64-linux.unison-sync = unison-sync "aarch64-linux";
		packages.x86_64-darwin.unison-sync = unison-sync "x86_64-darwin";
		packages.x86_64-linux.unison-sync = unison-sync "x86_64-linux";
		devShells.aarch64-darwin.default = shell "aarch64-darwin";
		devShells.aarch64-linux.default = shell "aarch64-linux";
		devShells.x86_64-darwin.default = shell "x86_64-darwin";
		devShells.x86_64-linux.default = shell "x86_64-linux";
		checks = self.packages;
	};
}
