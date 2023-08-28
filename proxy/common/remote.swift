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
		let query = "\(command)"
		let token = query.authenticate(key: apiKey, nonce: nonce)!
		let url = URL(string: "\(query)?\(token)", relativeTo: apiUrl)!

		return (url, nonce)
	}

	/// Requests the web service API to return the status of a remote VM.
	public func status() async -> Result<String?, Error> {
		let (url, nonce) = authenticatedUrl(forCommand: "status")

		let result = await request(url)

		switch result {
		case .nothing:
			return .success(nil)

		case .address(let ip, let token):
			guard let expectedToken = ip.authenticate(key: apiKey, nonce: nonce) else {
				return .failure(RequestError.invalidResponse(String(ip)))
			}
			guard expectedToken == token else {
				return .failure(RequestError.unauthorized(ip, token))
			}
			return .success(String(ip))

		case .error(let error):
			return .failure(error)
		}
	}

	/// Requests the web service API to launch a remote VM.
	public func launch() async -> Result<String, Error> {
		let (url, nonce) = authenticatedUrl(forCommand: "launch")

		let result = await request(url, method: "POST")

		switch result {
		case .nothing:
			return .failure(RequestError.invalidResponse(""))

		case .address(let ip, let token):
			guard let expectedToken = ip.authenticate(key: apiKey, nonce: nonce) else {
				return .failure(RequestError.invalidResponse(String(ip)))
			}
			guard expectedToken == token else {
				return .failure(RequestError.unauthorized(ip, token))
			}
			return .success(String(ip))

		case .error(let error):
			return .failure(error)
		}
	}

	public func terminate() async -> Result<Void, Error> {
		let (url, _) = authenticatedUrl(forCommand: "terminate")

		let result = await request(url, method: "POST")

		switch result {
		case .nothing:
			return .success(())
		case .address(let ip, let token):
			return .failure(RequestError.invalidResponse("\(ip) \(token)"))
		case .error(let error):
			return .failure(error)
		}
	}
}


/* MARK: HTTP Requests */

enum RequestResult {
	case nothing
	case address(ip: Substring, token: Substring)
	case error(_: RequestError)
}

enum RequestError: Error {
	case clientError(_: String)
	case serverError(_: String)
	case invalidResponse(_: String)
	case unauthorized(_: Substring, _: Substring)
	case noHTTPResponse
	case noResponseBody
}

func request(_ url: URL, method: String = "GET") async -> RequestResult {
	enum URLSessionStore {
		static let session: URLSession = {
#if os(Linux)
			let config = URLSessionConfiguration.default
#else
			let config = URLSessionConfiguration.ephemeral
#endif
			config.timeoutIntervalForRequest = 300
			config.httpCookieAcceptPolicy = .never
			config.httpShouldSetCookies = false
			config.urlCache = nil
			return URLSession(configuration: config)
		}()
	}

	var request = URLRequest(url: url)
	request.httpMethod = method

	do {
		let (data, response) = try await URLSessionStore.session.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			return .error(.noHTTPResponse)
		}
		guard (200...299).contains(httpResponse.statusCode) else {
			return .error(.serverError(httpResponse.description))
		}
		guard let responseBody = String(data: data, encoding: .utf8) else {
			return .error(.noResponseBody)
		}

		let trimmed = responseBody.trimmingCharacters(in: .newlines)
		let pieces = trimmed.split(separator: " ", maxSplits: 1)

		switch pieces.count {
		case 0:
			return .nothing
		case 2:
			return .address(ip: pieces[0], token: pieces[1])
		default:
			return .error(.invalidResponse(responseBody))
		}
	} catch {
		return .error(.clientError(error.localizedDescription))
	}
}
