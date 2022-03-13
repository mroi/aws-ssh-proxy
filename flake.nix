{
	description = "connect machines over SSH using Amazon EC2 VMs";
	inputs.swift-argument-parser = {
		url = "github:apple/swift-argument-parser";
		flake = false;
	};
	inputs.swift-crypto = {
		url = "github:apple/swift-crypto";
		flake = false;
	};
	outputs = { self, nixpkgs, swift-argument-parser, swift-crypto }:
		let
			ssh-proxy = system: with import nixpkgs {
				inherit system;
				overlays = [ (self: super: {
					# add swift to Xcode wrapper
					xcodeenv = super.xcodeenv // {
						composeXcodeWrapper = version: (super.xcodeenv.composeXcodeWrapper version).overrideAttrs (attrs: {
							buildCommand = attrs.buildCommand + ''
								cat <<- "EOF" > $out/bin/swift
									#!/bin/sh
									exec /usr/bin/swift "$@" --disable-sandbox
								EOF
								chmod a+x $out/bin/swift
							'';
						});
					};
				})];
			};
			clangStdenv.mkDerivation {
				name = "ssh-proxy-${lib.substring 0 8 self.lastModifiedDate}";
				src = self;
				nativeBuildInputs =
					lib.optional clangStdenv.isLinux swift ++
					lib.optionals clangStdenv.isDarwin [
						(xcodeenv.composeXcodeWrapper { version = "13.2.1"; })
						xcbuild
					];
				patchPhase = ''
					ln -s ${swift-argument-parser} swift-argument-parser
					ln -s ${swift-crypto} swift-crypto
					substituteInPlace proxy/Package.swift --replace 'url: "https://github.com/apple/swift-argument-parser.git"' 'path: "../swift-argument-parser"), //'
					substituteInPlace proxy/Package.swift --replace 'url: "https://github.com/apple/swift-crypto.git"' 'path: "../swift-crypto"), //'
					substituteInPlace proxy/common/proxy.swift --replace /usr/bin/ssh ${openssh}/bin/ssh
				'';
				makeFlags = [ "-C" "proxy" "DESTDIR=$(out)" "ENDPOINT=" "SECRET=" "SERVER=" "USERNAME=" ];
			};
		in {
			packages.x86_64-darwin.default = ssh-proxy "x86_64-darwin";
			packages.x86_64-linux.default = ssh-proxy "x86_64-linux";
		};
}
