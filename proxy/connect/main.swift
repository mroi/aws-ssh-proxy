import Foundation
import Dispatch
import ProxyUtil

sandbox()

do {
	let arguments = try parseArguments()

	// generate URL with authentication token
	let nonce = try random(bytes: 10)
	let query = "launch?\(arguments.endpoint)"
	let token = query.token(key: arguments.key, nonce: nonce)!
	let url = URL(string: "\(query)&\(token)", relativeTo: arguments.url)!

	var performRequest: (() -> Void)!
	performRequest = {
		request(url: url, method: "POST") { result in
			// check response of VM launch
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
					try ssh(mode: .connect, to: proxy.ip) { ssh in
						exit(ssh.terminationStatus)
					}
					return

				case .error(let error):
					throw error
				}
			}
			catch {
				print(error)
			}
			// retry until success
			DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
				performRequest()
			}
		}
	}
	performRequest()

	RunLoop.main.run()
}
catch let error as ArgumentError {
	print(error)
	print("Usage: ssh-connect --endpoint <name> --key <secret> --url <url>")
	exit(EX_USAGE)
}
catch let error as InternalError {
	print(error)
	exit(EX_SOFTWARE)
}
