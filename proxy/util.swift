import Foundation
import Security
import CommonCrypto

public func sandbox() -> Void {
	FileManager.default.changeCurrentDirectoryPath(Bundle.main.bundlePath)
	sandbox(home: NSHomeDirectory(), bundlePath: Bundle.main.bundlePath)
}

public enum ArgumentError: Error {
	case unknown(_: String)
	case missing(_: String)
	case invalid(_: String)
}

public enum InternalError: Error {
	case noBundleId
	case noRandom
	case noSSHConfig
}

public enum RequestError: Error {
	case clientError(_: String)
	case serverError(_: String)
	case invalidResponse(_: String)
	case unauthorized(_: (Substring, Substring))
	case noHTTPResponse
	case noResponse
}

public enum RequestResult {
	case nothing
	case proxy(ip: Substring, token: Substring)
	case error(_: RequestError)
}

public enum ProxyMode: String {
	case connect = "SSH_PROXY_CONNECT"
	case forward = "SSH_PROXY_FORWARD"
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

public func random(bytes: Int) throws -> Data {
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
	public func hmac(key: Data) -> Data {
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
	public func token(key: Data, nonce: Data) -> String? {
		guard let data = data(using: .ascii) else { return nil }
		let hmac = (nonce + data).hmac(key: key)
		return (nonce + hmac).base64EncodedString()
	}
}

public func request(url: URL, method: String = "GET", _ done: @escaping (RequestResult) -> Void) -> Void {
	struct URLSessionStore {
		static private var config: URLSessionConfiguration {
			let config = URLSessionConfiguration.ephemeral
			config.httpCookieAcceptPolicy = .never
			config.httpShouldSetCookies = false
			config.urlCache = nil
			return config
		}
		static let session = URLSession(configuration: config)
	}

	var request = URLRequest(url: url)
	request.httpMethod = method

	let task = URLSessionStore.session.dataTask(with: request) { data, response, error in
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
			done(.proxy(ip: pieces[0], token: pieces[1]))
		default:
			done(.error(.invalidResponse(response)))
		}
	}
	task.countOfBytesClientExpectsToReceive = 1024
	task.resume()
}

public func ssh(mode: ProxyMode, to ip: Substring, _ done: @escaping (Process) -> Void) throws {
	guard let config = Bundle.main.path(forResource: "ssh_config", ofType: nil) else {
		throw InternalError.noSSHConfig
	}

	let ssh = Process()
	ssh.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
	ssh.arguments = ["-F", config, String(ip)]
	ssh.environment = [mode.rawValue: "1"]
	ssh.terminationHandler = done
	try ssh.run()
}
