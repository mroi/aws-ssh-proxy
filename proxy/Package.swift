// swift-tools-version:5.2
import PackageDescription

func isLinux<T>(_ array: Array<T>) -> Array<T> {
  #if os(Linux)
	return array
  #else
	return []
  #endif
}

let package = Package(
	name: "SSHProxy",
	platforms: [
		.macOS(.v10_15)
	],
	products: [
		.executable(name: "ssh-connect", targets: ["Connect"]),
		.executable(name: "ssh-forward", targets: ["Forward"])
	],
	targets: [
		.target(name: "Connect", dependencies: ["SSHProxy"], path: "connect"),
		.target(name: "Forward", dependencies: ["SSHProxy"], path: "forward"),
		.target(name: "SSHProxy", dependencies: ["Sandbox"] + isLinux(["Sodium"]), path: "common", sources: ["proxy.swift"]),
		.target(name: "Sandbox", path: "common", sources: ["sandbox.c"], publicHeadersPath: ".")
	] + isLinux([
		.systemLibrary(name: "Sodium", path: "linux", pkgConfig: "libsodium")
	])
)
