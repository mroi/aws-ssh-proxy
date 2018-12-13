// swift-tools-version:4.2
import PackageDescription

let package = Package(
	name: "SSHProxy",
	products: [
		.executable(name: "ssh-connect", targets: ["Connect"]),
		.executable(name: "ssh-forward", targets: ["Forward"])
	],
	targets: [
		.target(name: "Connect", dependencies: ["ProxyUtil"], path: "connect"),
		.target(name: "Forward", dependencies: ["ProxyUtil"], path: "forward"),
		.target(name: "ProxyUtil", path: ".", exclude: ["connect", "forward", "sandbox.c"])
	]
)
