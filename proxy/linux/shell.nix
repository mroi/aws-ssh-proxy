with import <nixpkgs> {};
let swift = import ~/.nix-defexpr/swift.nix;
in (import ~/.nix-defexpr/local.nix).mkShellPlain {
	bin = [ swift php openssh ];
	lib = [ libsodium.dev ];
}
