// swift-tools-version:5.7
import PackageDescription

let package = Package(
	name: "SSHProxy",
	platforms: [
		.macOS(.v11)
	],
	products: [
		.executable(name: "ssh-connect", targets: ["Connect"]),
		.executable(name: "ssh-forward", targets: ["Forward"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0")
	],
	targets: [
		.executableTarget(name: "Connect", dependencies: ["RemoteVM"], path: "connect"),
		.executableTarget(name: "Forward", dependencies: ["RemoteVM"], path: "forward"),
		.target(name: "RemoteVM", dependencies: ["Sandbox",
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "Crypto", package: "swift-crypto")
		], path: "common", exclude: ["sandbox.c"], sources: ["remote.swift"]),
		.target(name: "Sandbox", path: "common", exclude: ["remote.swift"], sources: ["sandbox.c"], publicHeadersPath: ".")
	]
)
