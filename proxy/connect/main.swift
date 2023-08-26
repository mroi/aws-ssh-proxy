import Foundation
import Dispatch
import SSHProxy

sandbox()

do {
	let arguments = try parseArguments()

	// generate URL with authentication token
	let nonce = SecureData(randomBytes: 10)
	let query = "launch?\(arguments.endpoint)"
	let token = query.token(key: arguments.key, nonce: nonce)!
	let url = URL(string: "\(query)&\(token)", relativeTo: arguments.url)!

	request(url, method: "POST") { result in
		// check response of VM launch
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
				try ssh(mode: .connect, to: ip) { ssh in
					exit(ssh.terminationStatus)
				}
				return

			case .error(let error):
				throw error
			}
		} catch {
			print(error)
			exit(EX_PROTOCOL)
		}
	}

	RunLoop.main.run()
} catch let error as ArgumentError {
	print(error)
	print("Usage: ssh-connect --id <name> --api-url <server> --api-key <secret>")
	exit(EX_USAGE)
} catch let error as InternalError {
	print(error)
	exit(EX_SOFTWARE)
}
