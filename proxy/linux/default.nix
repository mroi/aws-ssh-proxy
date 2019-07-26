with import <nixpkgs> {};
clangStdenv.mkDerivation {
	name = "ssh-proxy-2019-07-26";
	src = fetchFromGitHub {
		owner = "mroi";
		repo = "aws-ssh-proxy";
		rev = "155a083";
		sha256 = "1dw0s5k63wy4f2mvr552x1knl02j1p0src5vy942x72rbfbpan5l";
	};
	nativeBuildInputs = [ swift pkg-config ];
	buildInputs = [ libsodium ];
	patchPhase = ''
		substituteInPlace proxy/util.swift --replace /usr/bin/ssh ${openssh}/bin/ssh
	'';
	makeFlags = [ "-C" "proxy" "DESTDIR=$(out)" ];
	dontBuild = true;
	installTargets = "all";
	meta = {
		description = "connect machines over SSH using Amazon EC2 VMs";
		homepage = https://github.com/mroi/aws-ssh-proxy;
		maintainers = [{
			email = "reactorcontrol@icloud.com";
			github = "mroi";
			name = "Michael Roitzsch";
		}];
		license = stdenv.lib.licenses.wtfpl;
	};
}
