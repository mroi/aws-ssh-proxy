import Foundation
import ProxyUtil

#if os(macOS)
import os.log
#endif

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
		guard let nonce = try? random(bytes: 10) else {
			print(InternalError.noRandom)
			exit(EX_SOFTWARE)
		}
		let query = "status?\(arguments.endpoint)"
		let token = query.token(key: arguments.key, nonce: nonce)!
		let url = URL(string: "\(query)&\(token)", relativeTo: arguments.url)!

		// query VM status and check response
		request(url: url) { result in
			do {
				switch result {
				case .nothing:
					break

				case .proxy(let proxy):
					guard let token = proxy.ip.token(key: arguments.key, nonce: nonce) else {
						throw RequestError.invalidResponse(String(proxy.ip))
					}
					guard token == proxy.token else {
						throw RequestError.unauthorized(proxy)
					}
					try ssh(mode: .forward, to: proxy.ip) { _ in
						// terminate proxy VM
						let query = "terminate?\(arguments.endpoint)"
						let token = query.token(key: arguments.key, nonce: nonce)!
						let url = URL(string: "\(query)&\(token)", relativeTo: arguments.url)!
						request(url: url, method: "POST") { _ in
							done(.finished)
						}
					}
					return

				case .error(let error):
					throw error
				}
			}
			catch {
			  #if os(macOS)
				os_log("%{public}s", type: .error, String(reflecting: error))
			  #elseif os(Linux)
				print(String(reflecting: error))
			  #endif
			}
			done(.finished)
		}
	}

	RunLoop.main.run()
}
catch let error as ArgumentError {
	print(error)
	print("Usage: ssh-forward --endpoint <name> --key <secret> --url <server>")
	exit(EX_USAGE)
}
catch let error as InternalError {
	print(error)
	exit(EX_SOFTWARE)
}
