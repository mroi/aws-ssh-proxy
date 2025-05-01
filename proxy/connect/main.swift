import RemoteVM
import PassFd

sandbox()

let remote = RemoteVM.parseOrExit()

switch await remote.launch() {

case .success(let ip):
	passConnection(to: ip, port: 22)

case .failure(let error):
	RemoteVM.exit(withError: error)
}
