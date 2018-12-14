import Foundation

public func sandbox() -> Void {
	sandbox(home: NSHomeDirectory(), bundlePath: Bundle.main.bundlePath)
}

public enum ArgumentError: Error {
	case unknown(_: String)
	case missing(_: String)
	case invalid(_: String)
}

public func parseArguments() throws -> (endpoint: String, key: Data, url: URL) {
	let arguments = CommandLine.arguments.dropFirst()
	var iterator = arguments.makeIterator()

	var endpointArgument: String?
	var keyArgument: String?
	var urlArgument: String?

	while let argument = iterator.next() {
		switch argument {
		case "--endpoint":
			endpointArgument = iterator.next()
		case "--key":
			keyArgument = iterator.next()
		case "--url":
			urlArgument = iterator.next()
		default:
			throw ArgumentError.unknown(argument)
		}
	}

	guard let endpoint = endpointArgument else {
		throw ArgumentError.missing("--endpoint")
	}
	guard let key = keyArgument else {
		throw ArgumentError.missing("--key")
	}
	guard var urlSanitized = urlArgument else {
		throw ArgumentError.missing("--url")
	}
	while urlSanitized.hasSuffix("/") {
		urlSanitized = String(urlSanitized.dropLast())
	}

	guard let _ = endpoint.data(using: .ascii) else {
		throw ArgumentError.invalid(endpoint)
	}
	guard let keyData = key.data(using: .utf8) else {
		throw ArgumentError.invalid(key)
	}
	guard let url = URL(string: urlSanitized) else {
		throw ArgumentError.invalid(urlSanitized)
	}

	return (endpoint, keyData, url)
}
