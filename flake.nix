{
	description = "connect machines over SSH using Amazon EC2 VMs";
	outputs = { self, nixpkgs }: let

		ssh-proxy = system:
			with nixpkgs.legacyPackages.${system}.extend (self: super: {
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
			});
			clangStdenv.mkDerivation {
				name = "ssh-proxy-${lib.substring 0 8 self.lastModifiedDate}";
				src = self;
				__noChroot = true;
				nativeBuildInputs =
					lib.optionals clangStdenv.buildPlatform.isLinux [
						swift swiftpm
					] ++ lib.optionals clangStdenv.buildPlatform.isDarwin [
						(xcodeenv.composeXcodeWrapper { version = "14.2"; })
						xcbuild
					];
				patchPhase = let
					swift-argument-parser = fetchFromGitHub {
						owner = "apple";
						repo = "swift-argument-parser";
						rev = "1.3.0";
						hash = "sha256-B4SwsR5v5dHaBZZMQsHmMh4oopkKWJgVl+k5yULaV3I=";
					};
					swift-crypto = fetchFromGitHub {
						owner = "apple";
						repo = "swift-crypto";
						rev = "3.1.0";
						hash = "sha256-3LS1QrhTevZs51/qtfuXPZpm62d4gEn8pqMsYfED0yM=";
					};
				in ''
					ln -s ${swift-argument-parser} swift-argument-parser
					ln -s ${swift-crypto} swift-crypto
					substituteInPlace proxy/Package.swift --replace 'url: "https://github.com/apple/swift-argument-parser.git"' 'path: "../swift-argument-parser"), //'
					substituteInPlace proxy/Package.swift --replace 'url: "https://github.com/apple/swift-crypto.git"' 'path: "../swift-crypto"), //'
					substituteInPlace proxy/common/ssh.swift --replace /usr/bin/ssh ${openssh}/bin/ssh
				'';
				dontUseSwiftpmBuild = true;
				makeFlags = [ "-C proxy" "DESTDIR=$(out)" "LOCAL_ID=" "API_URL=" "API_KEY=" "USERNAME=" ];
			};

		shell = system:
			with nixpkgs.legacyPackages.${system};
			mkShellNoCC {
				packages = [ php ] ++
					lib.optionals stdenv.isLinux [ clang swift swiftpm openssh ];
				shellHook = "test -r ~/.shellrc && . ~/.shellrc";
			};

	in {
		packages.x86_64-darwin.default = ssh-proxy "x86_64-darwin";
		packages.x86_64-linux.default = ssh-proxy "x86_64-linux";
		packages.x86_64-darwin.ssh-proxy = ssh-proxy "x86_64-darwin";
		packages.x86_64-linux.ssh-proxy = ssh-proxy "x86_64-linux";
		devShells.x86_64-darwin.default = shell "x86_64-darwin";
		devShells.x86_64-linux.default = shell "x86_64-linux";
	};
}
