import Darwin

import ProxyUtil

sandbox()

do {
	let arguments = try parseArguments()
}
catch let error as ArgumentError {
	print(error)
	print("Usage: ssh-connect --endpoint <name> --key <secret> --url <url>")
	exit(EX_USAGE)
}
