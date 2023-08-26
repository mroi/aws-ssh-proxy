import Foundation
import RemoteVM

sandbox()

let remote = RemoteVM.parseOrExit()

// schedule background activity
guard let bundleId = ProxyBundle.bundleIdentifier else {
	RemoteVM.exit(withError: InternalError.noBundleId)
}
let activity = NSBackgroundActivityScheduler(identifier: bundleId)
activity.interval = 5 * 60
activity.repeats = true
activity.qualityOfService = .utility
activity.schedule { done in

	Task {
		switch await remote.status() {

		case .success(.none):
			break

		case .success(.some(let ip)):
			do { try await ssh(mode: .forward, to: ip) }
			catch { RemoteVM.log(error) }
			let _ = await remote.terminate()

		case .failure(let error):
			RemoteVM.log(error)
		}

		done(.finished)
	}
}

RunLoop.main.run()
