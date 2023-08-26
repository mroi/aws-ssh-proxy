import Foundation
import RemoteVM

sandbox()

do {
	let arguments = try parseArguments()

	// schedule background activity
	guard let bundleId = ProxyBundle.bundleIdentifier else {
		throw InternalError.noBundleId
	}
	let activity = NSBackgroundActivityScheduler(identifier: bundleId)
	activity.interval = 5 * 60
	activity.repeats = true
	activity.qualityOfService = .utility
	activity.schedule { done in
		// generate URL with authentication token
		let nonce = SecureData(randomBytes: 10)
		let query = "status?\(arguments.endpoint)"
		let token = query.token(key: arguments.key, nonce: nonce)!
		let url = URL(string: "\(query)&\(token)", relativeTo: arguments.url)!

		// query VM status and check response
		request(url) { result in
			do {
				switch result {
				case .nothing:
					break

				case .proxy(let ip, let token):
					guard let expectedToken = ip.token(key: arguments.key, nonce: nonce) else {
						throw RequestError.invalidResponse(String(ip))
					}
					guard expectedToken == token else {
						throw RequestError.unauthorized(ip, token)
					}
					try ssh(mode: .forward, to: ip) { _ in
						// terminate proxy VM
						let query = "terminate?\(arguments.endpoint)"
						let token = query.token(key: arguments.key, nonce: nonce)!
						let url = URL(string: "\(query)&\(token)", relativeTo: arguments.url)!
						request(url, method: "POST") { _ in
							done(.finished)
						}
					}
					return

				case .error(let error):
					throw error
				}
			} catch {
				Logger().error("\(String(reflecting: error), privacy: .public)")
			}
			done(.finished)
		}
	}

	RunLoop.main.run()
} catch let error as ArgumentError {
	print(error)
	print("Usage: ssh-forward --id <name> --api-url <server> --api-key <secret>")
	exit(EX_USAGE)
} catch let error as InternalError {
	print(error)
	exit(EX_SOFTWARE)
}
