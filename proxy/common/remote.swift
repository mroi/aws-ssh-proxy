import ArgumentParser
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Sandbox


/// Enter a suitable sandbox.
///
/// This must be called very early, since entering a sanbox late will fail.
public func sandbox() -> Void {
	FileManager.default.changeCurrentDirectoryPath(ProxyBundle.bundlePath)
	sandbox(home: NSHomeDirectory(), bundlePath: ProxyBundle.bundlePath)
}


/* MARK: Command Line Options */

/// Parses command line arguments to interact with a remote VM.
public struct RemoteVM: ParsableCommand {

	public static var configuration = CommandConfiguration(commandName: CommandLine.arguments.first)

	@Option var id: String
	@Option var apiUrl: URL
	@Option(transform: SecureData.init) var apiKey: SecureData

	public init() {}
}

extension URL: ExpressibleByArgument {
	public init?(argument: String) {
		guard let url = URL.init(string: argument) else { return nil }
		self = url
	}
}


/* MARK: Remote VM Interaction */

extension RemoteVM {

	private func authenticatedUrl(forCommand command: String) -> (url: URL, nonce: SecureData) {
		let nonce = SecureData(randomBytes: 10)
		let query = "\(command)?\(id)"
		let token = query.authenticate(key: apiKey, nonce: nonce)!
		let url = URL(string: "\(query)&\(token)", relativeTo: apiUrl)!

		return (url, nonce)
	}

	/// Requests the web service API to return the status of a remote VM.
	public func status(_ continuation: @escaping (Substring?) throws -> Void) {
		let (url, nonce) = authenticatedUrl(forCommand: "status")

		request(url) { result in
			do {
				switch result {
				case .nothing:
					break

				case .proxy(let ip, let token):
					guard let expectedToken = ip.authenticate(key: apiKey, nonce: nonce) else {
						throw RequestError.invalidResponse(String(ip))
					}
					guard expectedToken == token else {
						throw RequestError.unauthorized(ip, token)
					}
					try continuation(ip)
					return

				case .error(let error):
					throw error
				}
			} catch {
				Logger().error("\(String(reflecting: error), privacy: .public)")
			}
			try! continuation(nil)
		}

	}

	/// Requests the web service API to launch a remote VM.
	public func launch(_ continuation: @escaping (Substring?) throws -> Void) {
		let (url, nonce) = authenticatedUrl(forCommand: "launch")

		request(url, method: "POST") { result in
			do {
				switch result {
				case .nothing:
					break

				case .proxy(let ip, let token):
					guard let expectedToken = ip.authenticate(key: apiKey, nonce: nonce) else {
						throw RequestError.invalidResponse(String(ip))
					}
					guard expectedToken == token else {
						throw RequestError.unauthorized(ip, token)
					}
					try continuation(ip)
					return

				case .error(let error):
					throw error
				}
			} catch {
				RemoteVM.exit(withError: error)
			}
			try! continuation(nil)
		}
	}

	public func terminate(_ continuation: @escaping () -> Void) {
		let (url, _) = authenticatedUrl(forCommand: "terminate")

		request(url, method: "POST") { _ in
			continuation()
		}
	}
}


/* MARK: HTTP Requests */

public enum RequestError: Error {
	case clientError(_: String)
	case serverError(_: String)
	case invalidResponse(_: String)
	case unauthorized(_: Substring, _: Substring)
	case noHTTPResponse
	case noResponse
}

public enum RequestResult {
	case nothing
	case proxy(ip: Substring, token: Substring)
	case error(_: RequestError)
}

public func request(_ url: URL, method: String = "GET", done: @escaping (RequestResult) -> Void) -> Void {
	struct URLSessionStore {
		static let session: URLSession = {
#if os(Linux)
			let config = URLSessionConfiguration.default
#else
			let config = URLSessionConfiguration.ephemeral
#endif
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
