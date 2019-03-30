// swift-tools-version:5.0
import PackageDescription

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
		.target(name: "ProxyUtil", dependencies: ["ProxySandbox"], path: ".", sources: ["util.swift"]),
		.target(name: "ProxySandbox", path: ".", sources: ["sandbox.c"], publicHeadersPath: ".")
	]
)
