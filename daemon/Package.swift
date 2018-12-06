// swift-tools-version:4.2
import PackageDescription

let package = Package(
	name: "SSHProxy",
	targets: [
		.target(name: "SSHProxy", path: ".", exclude: ["sandbox.c"])
	]
)
