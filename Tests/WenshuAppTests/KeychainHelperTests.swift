import XCTest
@testable import WenshuApp

final class KeychainHelperTests: XCTestCase {
    private let keychain = KeychainHelper.shared

    override func setUpWithError() throws {
        try? keychain.deleteKey()
    }

    override func tearDownWithError() throws {
        try? keychain.deleteKey()
    }

    func testSaveAndLoad() throws {
        try keychain.saveKey("test-key-A")
        XCTAssertEqual(keychain.loadKey(), "test-key-A")
    }

    func testOverwrite() throws {
        try keychain.saveKey("test-key-A")
        try keychain.saveKey("test-key-B")
        XCTAssertEqual(keychain.loadKey(), "test-key-B")
    }

    func testDelete() throws {
        try keychain.saveKey("test-key-A")
        try keychain.deleteKey()
        XCTAssertNil(keychain.loadKey())
    }
}
