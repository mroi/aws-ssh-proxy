import Foundation

enum ArgumentError: Error {
	case unknown(_: String)
	case missing(_: String)
}

func parseArguments() throws -> (client: String, secret: String, server: String) {
	let arguments = CommandLine.arguments.dropFirst()
	var iterator = arguments.makeIterator()

	var clientArgument: String?
	var secretArgument: String?
	var serverArgument: String?

	while let argument = iterator.next() {
		switch argument {
		case "--client":
			clientArgument = iterator.next()
		case "--key":
			secretArgument = iterator.next()
		case "--url":
			serverArgument = iterator.next()
		default:
			throw ArgumentError.unknown(argument)
		}
	}

	let clientArgumentSanitized = clientArgument?.unicodeScalars.filter {
		CharacterSet.alphanumerics.contains($0)
	}
	if let sanitized = clientArgumentSanitized {
		clientArgument = String(sanitized)
	}
	while serverArgument?.hasSuffix("/") ?? false {
		serverArgument = String(serverArgument!.dropLast())
	}

	guard let client = clientArgument else {
		throw ArgumentError.missing("--client")
	}
	guard let secret = secretArgument else {
		throw ArgumentError.missing("--key")
	}
	guard let server = serverArgument else {
		throw ArgumentError.missing("--url")
	}

	return (client, secret, server)
}


do {
	let arguments = try parseArguments()
}
catch let error as ArgumentError {
	print(error)
	print("Usage: SSHProxy --client <name> --key <secret> --url <url>")
	exit(EX_USAGE)
}
