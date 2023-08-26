import Foundation
import RemoteVM

sandbox()

let remote = RemoteVM.parseOrExit()

do {
	// schedule background activity
	guard let bundleId = ProxyBundle.bundleIdentifier else {
		throw InternalError.noBundleId
	}
	let activity = NSBackgroundActivityScheduler(identifier: bundleId)
	activity.interval = 5 * 60
	activity.repeats = true
	activity.qualityOfService = .utility
	activity.schedule { done in
		remote.status { ip in
			guard let ip else { done(.finished) ; return }
			try ssh(mode: .forward, to: ip) { _ in
				remote.terminate {
					done(.finished)
				}
			}
		}
	}

	RunLoop.main.run()
} catch let error as InternalError {
	print(error)
	exit(EX_SOFTWARE)
}
