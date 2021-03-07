// swift-tools-version:5.3
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
		.macOS(.v11)
	],
	products: [
		.executable(name: "ssh-connect", targets: ["Connect"]),
		.executable(name: "ssh-forward", targets: ["Forward"])
	],
	dependencies: isLinux([
		.package(url: "https://github.com/apple/swift-crypto.git", from: "1.0.0")
	]),
	targets: [
		.target(name: "Connect", dependencies: ["SSHProxy"], path: "connect"),
		.target(name: "Forward", dependencies: ["SSHProxy"], path: "forward"),
		.target(name: "SSHProxy", dependencies: ["Sandbox"] + isLinux(["Crypto"]), path: "common", exclude: ["sandbox.c"], sources: ["proxy.swift"]),
		.target(name: "Sandbox", path: "common", exclude: ["proxy.swift"], sources: ["sandbox.c"], publicHeadersPath: ".")
	]
)
