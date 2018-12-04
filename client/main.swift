import Foundation
import Security
import CommonCrypto
import Dispatch
import Darwin
import os.log


enum ArgumentError: Error {
	case unknown(_: String)
	case missing(_: String)
	case invalid(_: String)
}

enum InternalError: Error {
	case noBundleId
	case noRandom
}

enum RequestError: Error {
	case clientError(_: String)
	case serverError(_: String)
	case mimeType(_: String)
	case invalidResponse(_: String)
	case unauthorized(_: (Substring, Substring))
	case noHTTPResponse
	case noMimeType
	case noResponse
}

enum RequestResult {
	case nothing
	case forward(ip: Substring, token: Substring)
	case error(_: RequestError)
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
		throw InternalError.noRandom
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

func request(url: URL, _ done: @escaping (RequestResult) -> Void) -> Void {
	let task = URLSession.shared.dataTask(with: url) { data, response, error in
		guard error == nil else {
			done(.error(.clientError(error!.localizedDescription)))
			return
		}
		guard let httpResponse = response as? HTTPURLResponse else {
			done(.error(.noHTTPResponse))
			return
		}
		guard (200...299).contains(httpResponse.statusCode) else {
			done(.error(.serverError(String(httpResponse.statusCode))))
			return
		}
		guard let mimeType = httpResponse.mimeType else {
			done(.error(.noMimeType))
			return
		}
		guard mimeType == "text/plain" else {
			done(.error(.mimeType(mimeType)))
			return
		}
		guard let data = data, let response = String(data: data, encoding: .utf8) else {
			done(.error(.noResponse))
			return
		}

		let pieces = response.split(separator: " ", maxSplits: 1)
		switch pieces.count {
		case 0:
			done(.nothing)
		case 2:
			done(.forward(ip: pieces[0], token: pieces[1]))
		default:
			done(.error(.invalidResponse(response)))
		}
		return
	}
	task.resume()
}

func forwardSSH(ip: Substring) {
}


// MARK: - main code

do {
	let arguments = try parseArguments()

	// prepare static data
	let query = "status?\(arguments.client)"
	guard let queryData = query.data(using: .ascii) else {
		throw ArgumentError.invalid(arguments.client)
	}
	guard let secretData = arguments.secret.data(using: .utf8) else {
		throw ArgumentError.invalid(arguments.secret)
	}
	guard let baseURL = URL(string: arguments.server) else {
		throw ArgumentError.invalid(arguments.server)
	}

	// schedule background activity
	guard let bundleId = Bundle.main.bundleIdentifier else {
		throw InternalError.noBundleId
	}
	let activity = NSBackgroundActivityScheduler(identifier: bundleId)
	activity.interval = 5 * 60
	activity.repeats = true
	activity.qualityOfService = .utility
	activity.schedule { done in
		// generate URL with authentication token
		guard let nonce = try? random(bytes: 10) else {
			print(InternalError.noRandom)
			exit(EX_SOFTWARE)
		}
		let hmac = (nonce + queryData).hmac(key: secretData)
		let token = (nonce + hmac).base64EncodedString()
		let url = URL(string: "\(query)&\(token)", relativeTo: baseURL)!

		// query AWS and check response
		request(url: url) { result in
			do {
				switch result {
				case .nothing:
					break

				case .forward(let forward):
					guard let ipData = forward.ip.data(using: .ascii) else {
						throw RequestError.invalidResponse(String(forward.ip))
					}
					let hmac = (nonce + ipData).hmac(key: secretData)
					let token = (nonce + hmac).base64EncodedString()
					guard token == forward.token else {
						throw RequestError.unauthorized(forward)
					}
					forwardSSH(ip: forward.ip)

				case .error(let error):
					throw error
				}
			}
			catch {
				os_log("%{public}s", String(reflecting: error))
			}
			done(.finished)
		}
	}

	dispatchMain()
}
catch let error as ArgumentError {
	print(error)
	print("Usage: SSHProxy --client <name> --key <secret> --url <url>")
	exit(EX_USAGE)
}
catch let error as InternalError {
	print(error)
	exit(EX_SOFTWARE)
}
