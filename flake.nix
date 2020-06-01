{
	description = "connect machines over SSH using Amazon EC2 VMs";
	inputs.swift-crypto = {
		url = github:apple/swift-crypto;
		flake = false;
	};
	outputs = { self, nixpkgs, swift-crypto }: {
		defaultPackage.x86_64-linux =
			with import nixpkgs { system = "x86_64-linux"; };
			clangStdenv.mkDerivation {
				name = "ssh-proxy-${lib.substring 0 8 self.lastModifiedDate}";
				src = self;
				nativeBuildInputs = [ swift ];
				patchPhase = ''
					substituteInPlace proxy/Package.swift --replace 'url: "https://github.com/apple/swift-crypto.git"' 'path: "${swift-crypto}") //'
					substituteInPlace proxy/common/proxy.swift --replace /usr/bin/ssh ${openssh}/bin/ssh
				'';
				makeFlags = [ "-C" "proxy" "DESTDIR=$(out)" ];
				dontBuild = true;
				installTargets = "all";
			};
	};
}
