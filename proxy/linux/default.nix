with import <nixpkgs> {};
clangStdenv.mkDerivation {
	name = "ssh-proxy-2019-07-24";
	src = fetchFromGitHub {
		owner = "mroi";
		repo = "aws-ssh-proxy";
		rev = "f8972d4";
		sha256 = "1ig8ankyzid1a2lglq1rs0kma1av40n19ghhcz67bfly89c5c554";
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
