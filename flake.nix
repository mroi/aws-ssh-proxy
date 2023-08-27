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
					lib.optionals clangStdenv.isLinux [
						swift swiftpm
					] ++ lib.optionals clangStdenv.isDarwin [
						(xcodeenv.composeXcodeWrapper { version = "14.2.1"; })
						xcbuild
					];
				patchPhase = ''
					ln -s ${swift-argument-parser} swift-argument-parser
					ln -s ${swift-crypto} swift-crypto
					substituteInPlace proxy/Package.swift --replace 'url: "https://github.com/apple/swift-argument-parser.git"' 'path: "../swift-argument-parser"), //'
					substituteInPlace proxy/Package.swift --replace 'url: "https://github.com/apple/swift-crypto.git"' 'path: "../swift-crypto"), //'
					substituteInPlace proxy/common/ssh.swift --replace /usr/bin/ssh ${openssh}/bin/ssh
				'';
				dontUseSwiftpmBuild = true;
				makeFlags = [ "-C" "proxy" "PREFIX=$(out)" "LOCAL_ID=" "API_URL=" "API_KEY=" "USERNAME=" ];
			};

			shell = system: with import nixpkgs { inherit system; };
			mkShellNoCC {
				packages = [ php ] ++
					lib.optionals stdenv.isLinux [ clang swift swiftpm openssh ];
				shellHook = "test -r ~/.shellrc && . ~/.shellrc";
			};

		in {
			packages.x86_64-darwin.default = ssh-proxy "x86_64-darwin";
			packages.x86_64-linux.default = ssh-proxy "x86_64-linux";
			devShells.x86_64-darwin.default = shell "x86_64-darwin";
			devShells.x86_64-linux.default = shell "x86_64-linux";
		};
}
