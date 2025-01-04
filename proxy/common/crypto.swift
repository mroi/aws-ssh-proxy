import Foundation
import Crypto


/// Stores byte data that gets zeroed whenever the instance is deallocated.
///
/// - Note: Sendability is unchecked, but warranted, because after initialization,
///   the members of the class cannot be mutated through its public API.
class SecureData: @unchecked Sendable {
	typealias Buffer = UnsafeMutableBufferPointer<UInt8>
	private let buffer: Buffer
	init(string: String) {
		assert(string.isContiguousUTF8)  // make sure we do not create temp copies
		buffer = Buffer.allocate(capacity: string.lengthOfBytes(using: .utf8))
		let copied = string.utf8.withContiguousStorageIfAvailable {
			$0.copyBytes(to: buffer)
		}
		assert(copied == buffer.count)
	}
	init(randomBytes: Int) {
		let nonce = AES.GCM.Nonce()
		buffer = Buffer.allocate(capacity: randomBytes)
		let copied = nonce.withUnsafeBytes {
			$0.copyBytes(to: buffer)
		}
		assert(copied == buffer.count)
		assert(copied == randomBytes)
	}
	deinit {
		// zero the contents of the buffer
		memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
		buffer.deallocate()
	}
}

extension SecureData: Sequence, ContiguousBytes {
	public func makeIterator() -> Buffer.Iterator {
		return buffer.makeIterator()
	}
	public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
		return try buffer.withUnsafeBytes(body)
	}
}

extension Data {
	func hmac(key: SecureData) -> Data {
		let mac = HMAC<SHA256>.authenticationCode(for: self, using: SymmetricKey(data: key))
		return Data(mac)
	}
}

extension StringProtocol where Index == String.Index {
	func authenticate(key: SecureData, nonce: SecureData) -> String? {
		guard let data = data(using: .ascii) else { return nil }
		let hmac = (nonce + data).hmac(key: key)
		return (nonce + hmac).base64EncodedString()
	}
}
