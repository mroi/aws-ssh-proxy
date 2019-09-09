with import <nixpkgs> {};
let swift = import ~/.nix-defexpr/swift.nix;
in (import ~/.nix-defexpr/local.nix).mkShellPlain {
	bin = [ php ] ++ stdenv.lib.optionals stdenv.isLinux [ swift pkg-config openssh ];
	lib = stdenv.lib.optionals stdenv.isLinux [ libsodium.dev ];
}