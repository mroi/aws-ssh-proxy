// swift-tools-version:5.1
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
		.macOS(.v10_14)
	],
	products: [
		.executable(name: "ssh-connect", targets: ["Connect"]),
		.executable(name: "ssh-forward", targets: ["Forward"])
	],
	targets: [
		.target(name: "Connect", dependencies: ["ProxyUtil"], path: "connect"),
		.target(name: "Forward", dependencies: ["ProxyUtil"], path: "forward"),
		.target(name: "ProxyUtil", dependencies: ["ProxySandbox"] + isLinux(["Sodium"]), path: ".", sources: ["util.swift"]),
		.target(name: "ProxySandbox", path: ".", sources: ["sandbox.c"], publicHeadersPath: ".")
	] + isLinux([
		.systemLibrary(name: "Sodium", path: "linux", pkgConfig: "libsodium")
	])
)
