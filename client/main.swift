import Foundation
import Security
import CommonCrypto
import Dispatch


enum ArgumentError: Error {
	case unknown(_: String)
	case missing(_: String)
	case invalid(_: String)
}

enum QueryError: Error {
	case noRandom
	case clientError(_: String)
	case serverError(_: String)
	case mimeType(_: String)
	case noHTTPResponse
	case noMimeType
	case noData
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

func random(bytes: Int) throws -> Data {
	var data = Data(count: bytes)
	let result = data.withUnsafeMutableBytes {
		SecRandomCopyBytes(kSecRandomDefault, bytes, $0)
	}
	guard result == errSecSuccess else {
		throw QueryError.noRandom
	}
	return data
}

extension Data {
	func hmac(key: Data) -> Data {
		let keyLength = key.count
		let dataLength = count
		let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)
		let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
		return withUnsafeBytes { (data: UnsafePointer<UInt8>) -> Data in
			let result = UnsafeMutablePointer<UInt8>.allocate(capacity: digestLength)
			defer { result.deallocate() }
			key.withUnsafeBytes { key in
				CCHmac(algorithm, key, keyLength, data, dataLength, result)
			}
			return Data(bytes: result, count: digestLength)
		}
	}
}

func request(url: URL) throws -> (ip: String, token: String)? {
	let completion = DispatchSemaphore(value: 0)
	var requestError: QueryError?
	var result: String?

	let task = URLSession.shared.dataTask(with: url) { data, response, error in
		defer { completion.signal() }
		guard error == nil else {
			requestError = QueryError.clientError(error!.localizedDescription)
			return
		}
		guard let httpResponse = response as? HTTPURLResponse else {
			requestError = QueryError.noHTTPResponse
			return
		}
		guard (200...299).contains(httpResponse.statusCode) else {
			requestError = QueryError.serverError(String(httpResponse.statusCode))
			return
		}
		guard let mimeType = httpResponse.mimeType else {
			requestError = QueryError.noMimeType
			return
		}
		guard mimeType == "text/plain" else {
			requestError = QueryError.mimeType(mimeType)
			return
		}
		guard let data = data, let string = String(data: data, encoding: .utf8) else {
			requestError = QueryError.noData
			return
		}

		result = string
	}
	task.resume()
	completion.wait()

	if requestError != nil {
		throw requestError!
	}
	guard let pieces = result?.split(separator: " ", maxSplits: 1), pieces.count == 2 else {
			return nil
	}
	return (String(pieces[0]), String(pieces[1]))
}


do {
	let arguments = try parseArguments()

	// prepare static pieces
	let query = "status?\(arguments.client)"
	guard let queryData = query.data(using: .ascii) else {
		throw ArgumentError.invalid(arguments.client)
	}
	guard let secretData = arguments.secret.data(using: .ascii) else {
		throw ArgumentError.invalid(arguments.secret)
	}
	guard let baseURL = URL(string: arguments.server) else {
		throw ArgumentError.invalid(arguments.server)
	}

	// generate URL with authentication token
	let nonce = try random(bytes: 10)
	let hmac = (nonce + queryData).hmac(key: secretData)
	let token = (nonce + hmac).base64EncodedString()
	let url = URL(string: "\(query)&\(token)", relativeTo: baseURL)!

	// query AWS
	let response = try request(url: url)
}
catch let error as ArgumentError {
	print(error)
	print("Usage: SSHProxy --client <name> --key <secret> --url <url>")
	exit(EX_USAGE)
}
catch let error as QueryError {
	print(error)
	exit(EX_UNAVAILABLE)
}
