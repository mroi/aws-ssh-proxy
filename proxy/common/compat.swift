import Foundation
import Dispatch


/* MARK: Bundle Resources */

public struct ProxyBundle {
#if os(macOS)
	public static var bundleIdentifier: String? { return Bundle.main.bundleIdentifier }
	public static var bundlePath: String { return Bundle.main.bundlePath }
	public static func path(forResource name: String?, ofType type: String?) -> String? {
		return Bundle.main.path(forResource: name, ofType: type)
	}
#elseif os(Linux)
	public static var bundleIdentifier: String? { return "ssh-proxy" }
	public static let bundlePath: String = {
		let executable = URL(fileURLWithPath: "/proc/self/exe").resolvingSymlinksInPath()
		let binDir = executable.deletingLastPathComponent()
		var bundleDir = binDir.appendingPathComponent("../share/ssh-proxy", isDirectory: true)
		bundleDir.standardize()
		return bundleDir.path
	}()
	public static func path(forResource name: String?, ofType type: String?) -> String? {
		guard let name = name else { return nil }
		let bundleDir = URL(fileURLWithPath: bundlePath)
		let resource: URL
		if let type = type {
			resource = bundleDir.appendingPathComponent(name + "." + type)
		} else {
			resource = bundleDir.appendingPathComponent(name)
		}
		if let result = try? resource.checkResourceIsReachable(), result {
			return resource.path
		} else {
			return nil
		}
	}
#endif
}


/* MARK: Background Activity */

#if os(Linux)
public class NSBackgroundActivityScheduler {
	public typealias CompletionHandler = (Result) -> Void
	public enum Result {
		case finished
	}
	public let identifier: String
	public var interval: TimeInterval = .infinity
	public var repeats: Bool = false
	public var qualityOfService: DispatchQoS = .unspecified
	public init(identifier: String) {
		self.identifier = identifier
	}
	public func schedule(_ block: @escaping (@escaping CompletionHandler) -> Void) {
		let queue = DispatchQueue(label: identifier, qos: qualityOfService)
		var time = DispatchTime.now() + interval
		func recurse(_ block: @escaping (@escaping () -> Void) -> Void) -> () -> Void {
			return { block(recurse(block)) }
		}
		let work = DispatchWorkItem(block: recurse { next in
			block { _ in }
			if self.repeats && self.interval < .infinity {
				time = time + self.interval
				queue.asyncAfter(deadline: time, execute: next)
			}
		})
		queue.asyncAfter(deadline: time, execute: work)
	}
}
#endif


/* MARK: Logging */

#if os(macOS)
import os
extension RemoteVM {
	public static func log(_ error: Error) {
		Logger().error("\(String(reflecting: error), privacy: .public)")
	}
}
#elseif os(Linux)
extension RemoteVM {
	public static func log(_ error: Error) {
		print(String(reflecting: error))
	}
}
#endif
