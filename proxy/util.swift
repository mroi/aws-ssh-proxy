import Foundation
import ProxySandbox


// Mark: - Types and Initialization

public func sandbox() -> Void {
	FileManager.default.changeCurrentDirectoryPath(ProxyBundle.bundlePath)
	sandbox(home: NSHomeDirectory(), bundlePath: ProxyBundle.bundlePath)
}

public struct ProxyBundle {
  #if os(macOS)
	public static var bundleIdentifier: String? { return Bundle.main.bundleIdentifier }
	public static var bundlePath: String { return Bundle.main.bundlePath }
	public static func path(forResource name: String?, ofType type: String?) -> String? {
		return Bundle.main.path(forResource: name, ofType: type)
	}
  #elseif os(Linux)
	public static var bundleIdentifier: String? { return "ssh-proxy" }
	public static let bundlePath: String = {
		let executable = URL(fileURLWithPath: "/proc/self/exe").resolvingSymlinksInPath()
		let binDir = executable.deletingLastPathComponent()
		var bundleDir = binDir.appendingPathComponent("../share/ssh-proxy", isDirectory: true)
		bundleDir.standardize()
		return bundleDir.path
	}()
	public static func path(forResource name: String?, ofType type: String?) -> String? {
		guard let name = name else { return nil }
		let bundleDir = URL(fileURLWithPath: bundlePath)
		let resource: URL
		if let type = type {
			resource = bundleDir.appendingPathComponent(name + "." + type)
		} else {
			resource = bundleDir.appendingPathComponent(name)
		}
		if let result = try? resource.checkResourceIsReachable(), result {
			return resource.path
		} else {
			return nil
		}
	}
  #endif
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


// MARK: - Cryptography

#if os(macOS)

import Security
import CommonCrypto

public func random(bytes: Int) throws -> Data {
	var data = Data(count: bytes)
	let result = data.withUnsafeMutableBytes {
		SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
	}
	guard result == errSecSuccess else {
		throw InternalError.noRandom
	}
	return data
}

extension Data {
	public func hmac(key: Data) -> Data {
		let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)
		let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
		return withUnsafeBytes { data in
			let result = UnsafeMutablePointer<UInt8>.allocate(capacity: digestLength)
			defer { result.deallocate() }
			key.withUnsafeBytes { key in
				CCHmac(algorithm, key.baseAddress!, key.count, data.baseAddress!, data.count, result)
			}
			return Data(bytes: result, count: digestLength)
		}
	}
}

#elseif os(Linux)

// FIXME: implement random and HMac on Linux
public func random(bytes: Int) throws -> Data {
	return Data(count: bytes)
}

extension Data {
	public func hmac(key: Data) -> Data {
		return Data(count: 64)
	}
}

#endif

extension StringProtocol where Index == String.Index {
	public func token(key: Data, nonce: Data) -> String? {
		guard let data = data(using: .ascii) else { return nil }
		let hmac = (nonce + data).hmac(key: key)
		return (nonce + hmac).base64EncodedString()
	}
}


// MARK: - HTTP & SSH

public func request(url: URL, method: String = "GET", _ done: @escaping (RequestResult) -> Void) -> Void {
	struct URLSessionStore {
		static let session: URLSession = {
			let config = URLSessionConfiguration.ephemeral
			config.httpCookieAcceptPolicy = .never
			config.httpShouldSetCookies = false
			config.urlCache = nil
			return URLSession(configuration: config)
		}()
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
	task.resume()
}

public func ssh(mode: ProxyMode, to ip: Substring, _ done: @escaping (Process) -> Void) throws {
	class SignalHandler {
		static let shared = SignalHandler()
		var subprocess: Process?
		private init() {
			func handler(signal: Int32) -> Void {
				SignalHandler.shared.subprocess?.terminate()
				exit(signal)
			}
			signal(SIGHUP, handler)
			signal(SIGINT, handler)
			signal(SIGPIPE, handler)
			signal(SIGTERM, handler)
		}
	}

	guard let config = ProxyBundle.path(forResource: "ssh_config", ofType: nil) else {
		throw InternalError.noSSHConfig
	}

	let ssh = Process()
	SignalHandler.shared.subprocess = ssh
	ssh.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
	ssh.arguments = ["-F", config, String(ip)]
	ssh.environment = [mode.rawValue: "1"]
	ssh.terminationHandler = done
	try ssh.run()
}


#if os(Linux)
// MARK: - Background Activity

public class NSBackgroundActivityScheduler {
	public enum QualityOfService {
		case utility
		case `default`
	}
	public typealias CompletionHandler = (NSBackgroundActivityScheduler.Result) -> Void
	public enum Result {
		case finished
	}
	public var interval: TimeInterval = .infinity
	public var repeats: Bool = false
	public var qualityOfService: QualityOfService = .default
	public init(identifier: String) {}
	public func schedule(_ block: @escaping (@escaping NSBackgroundActivityScheduler.CompletionHandler) -> Void) {}
}
#endif
