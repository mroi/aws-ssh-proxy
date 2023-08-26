import Foundation


public enum InternalError: Error {
	case noBundleId
	case noSSHConfig
}

public enum ProxyMode: String {
	case connect = "SSH_PROXY_CONNECT"
	case forward = "SSH_PROXY_FORWARD"
}

public func ssh(mode: ProxyMode, to ip: String, _ done: @escaping (Process) -> Void) throws {
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
	ssh.arguments = ["-F", config, ip]
	ssh.environment = [mode.rawValue: "1"]
	ssh.terminationHandler = done
	try ssh.run()
}
