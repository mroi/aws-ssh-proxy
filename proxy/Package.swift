// swift-tools-version:6.0
import PackageDescription

let package = Package(
	name: "SSHProxy",
	platforms: [
		.macOS(.v11)
	],
	products: [
		.executable(name: "ssh-connect", targets: ["Connect"]),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "4.0.0")
	],
	targets: [
		.executableTarget(name: "Connect", dependencies: ["RemoteVM"], path: "connect"),
		.target(name: "RemoteVM", dependencies: ["Sandbox",
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "Crypto", package: "swift-crypto")
		], path: "common", exclude: ["sandbox.c"]),
		.target(name: "Sandbox", path: "common", sources: ["sandbox.c"], publicHeadersPath: ".")
	]
)
