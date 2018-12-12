// swift-tools-version:4.2
import PackageDescription

let package = Package(
	name: "SSHProxy",
	products: [
		.executable(name: "ssh-forward", targets: ["Forward"])
	],
	targets: [
		.target(name: "Forward", path: "forward")
	]
)
