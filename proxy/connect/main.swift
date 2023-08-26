import Foundation
import RemoteVM

sandbox()

let remote = RemoteVM.parseOrExit()

remote.launch { ip in
	guard let ip else { return }
	try ssh(mode: .connect, to: ip) { ssh in
		exit(ssh.terminationStatus)
	}
}

RunLoop.main.run()
