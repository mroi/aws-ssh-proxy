import Foundation
import Security
import CommonCrypto
import Dispatch
import Darwin
import os.log

sandbox(bundlePath: Bundle.main.bundlePath)


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
	case invalidResponse(_: String)
	case unauthorized(_: (Substring, Substring))
	case noHTTPResponse
	case noResponse
}

enum RequestResult {
	case nothing
	case forward(ip: Substring, token: Substring)
	case error(_: RequestError)
}


func parseArguments() throws -> (endpoint: String, key: String, url: String) {
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

	let endpointArgumentSanitized = endpointArgument?.unicodeScalars.filter {
		CharacterSet.alphanumerics.contains($0)
	}
	if let sanitized = endpointArgumentSanitized {
		endpointArgument = String(sanitized)
	}
	while urlArgument?.hasSuffix("/") ?? false {
		urlArgument = String(urlArgument!.dropLast())
	}

	guard let endpoint = endpointArgument else {
		throw ArgumentError.missing("--endpoint")
	}
	guard let key = keyArgument else {
		throw ArgumentError.missing("--key")
	}
	guard let url = urlArgument else {
		throw ArgumentError.missing("--url")
	}

	return (endpoint, key, url)
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

extension StringProtocol where Index == String.Index {
	func token(key: Data, nonce: Data) -> String? {
		guard let data = data(using: .ascii) else { return nil }
		let hmac = (nonce + data).hmac(key: key)
		return (nonce + hmac).base64EncodedString()
	}
}

let session = URLSession(configuration: .ephemeral)

func request(url: URL, _ done: @escaping (RequestResult) -> Void) -> Void {
	let task = session.dataTask(with: url) { data, response, error in
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
		guard let data = data, let response = String(data: data, encoding: .utf8) else {
			done(.error(.noResponse))
			return
		}

		let trimmed = response.trimmingCharacters(in: .newlines)
		let pieces = trimmed.split(separator: " ", maxSplits: 1)
		switch pieces.count {
		case 0:
			done(.nothing)
		case 2:
			done(.forward(ip: pieces[0], token: pieces[1]))
		default:
			done(.error(.invalidResponse(response)))
		}
	}
	task.resume()
}

func forwardSSH(ip: Substring, _ done: @escaping () -> Void) {
	done()
}


// MARK: - main code

do {
	let arguments = try parseArguments()

	// prepare static data
	guard let _ = arguments.endpoint.data(using: .ascii) else {
		throw ArgumentError.invalid(arguments.endpoint)
	}
	guard let keyData = arguments.key.data(using: .utf8) else {
		throw ArgumentError.invalid(arguments.key)
	}
	guard let baseURL = URL(string: arguments.url) else {
		throw ArgumentError.invalid(arguments.url)
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
		let query = "status?\(arguments.endpoint)"
		let token = query.token(key: keyData, nonce: nonce)!
		let url = URL(string: "\(query)&\(token)", relativeTo: baseURL)!

		// query AWS and check response
		request(url: url) { result in
			do {
				switch result {
				case .nothing:
					break

				case .forward(let forward):
					guard let token = forward.ip.token(key: keyData, nonce: nonce) else {
						throw RequestError.invalidResponse(String(forward.ip))
					}
					guard token == forward.token else {
						throw RequestError.unauthorized(forward)
					}
					forwardSSH(ip: forward.ip) {
						let query = "terminate?\(arguments.endpoint)"
						let token = query.token(key: keyData, nonce: nonce)!
						let url = URL(string: "\(query)&\(token)", relativeTo: baseURL)!
						request(url: url) { _ in
							done(.finished)
						}
					}
					return

				case .error(let error):
					throw error
				}
			}
			catch {
				os_log("%{public}s", type: .error, String(reflecting: error))
			}
			done(.finished)
		}
	}

	dispatchMain()
}
catch let error as ArgumentError {
	print(error)
	print("Usage: SSHProxy --endpoint <name> --key <secret> --url <url>")
	exit(EX_USAGE)
}
catch let error as InternalError {
	print(error)
	exit(EX_SOFTWARE)
}
