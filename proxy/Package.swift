// swift-tools-version:5.7
import PackageDescription

let package = Package(
	name: "UnisonSync",
	platforms: [
		.macOS(.v11)
	],
	products: [
		.executable(name: "unison-connect", targets: ["Connect"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "4.0.0")
	],
	targets: [
		.executableTarget(name: "Connect", dependencies: ["RemoteVM", "PassFd"], path: "connect", exclude: ["passfd.c"]),
		.target(name: "RemoteVM", dependencies: ["Sandbox",
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "Crypto", package: "swift-crypto")
		], path: "common", exclude: ["sandbox.c"]),
		.target(name: "PassFd", path: "connect", sources: ["passfd.c"], publicHeadersPath: "."),
		.target(name: "Sandbox", path: "common", sources: ["sandbox.c"], publicHeadersPath: ".")
	]
)
