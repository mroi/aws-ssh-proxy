import Foundation

enum ArgumentError: Error {
	case unknown(_: String)
	case missing(_: String)
}

do {
	/* parse arguments */
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

	// FIXME: clientArgument?.removeAll(where: { CharacterSet.alphanumerics.contains($0) })
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
}
catch let error as ArgumentError {
	print(error)
	print("Usage: SSHProxy --client <name> --key <secret> --url <url>")
	exit(EX_USAGE)
}
