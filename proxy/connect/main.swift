import RemoteVM

sandbox()

let remote = RemoteVM.parseOrExit()

switch await remote.launch() {

case .success(let ip):
	// FIXME: connect and pass file descriptor
	print(ip)

case .failure(let error):
	RemoteVM.exit(withError: error)
}
