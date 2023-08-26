import RemoteVM

sandbox()

let remote = RemoteVM.parseOrExit()

switch await remote.launch() {

case .success(let ip):
	try await ssh(mode: .connect, to: ip)

case .failure(let error):
	RemoteVM.exit(withError: error)
}
