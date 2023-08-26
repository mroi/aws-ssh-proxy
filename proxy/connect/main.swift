import RemoteVM

sandbox()

let remote = RemoteVM.parseOrExit()

switch await remote.launch() {

case .success(let ip):
	try ssh(mode: .connect, to: ip) { _ in
		RemoteVM.exit()
	}

case .failure(let error):
	RemoteVM.exit(withError: error)
}
