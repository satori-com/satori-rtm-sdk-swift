import XCTest
import Starscream

class websocketTests: XCTestCase {
    func badSSL(_ address: String) {
        let ws = WebSocket(url: URL(string: address)!)
        let exp = XCTestExpectation()
        ws.onDisconnect = { error in
            XCTAssertNotNil(error)
            exp.fulfill()
        }
        ws.callbackQueue = DispatchQueue.main
        ws.connect()
        wait(for: [exp], timeout: 10.0)
        XCTAssertFalse(ws.isConnected)
    }

    func testSelfSignedBadSSL() {
        self.badSSL("wss://self-signed.badssl.com")
    }

    func testExpiredBadSSL() {
        self.badSSL("wss://expired.badssl.com")
    }

    func testWrongHostBadSSL() {
        self.badSSL("wss://wrong.host.badssl.com")
    }

    static var allTests : [(String, (websocketTests) -> () throws -> Void)] {
        return [
            // TODO: collect all these automatically somehow
            //       adding those manually is too error-prone
            ("testSelfSignedBadSSL", testSelfSignedBadSSL),
            ("testExpiredBadSSL", testExpiredBadSSL),
            ("testWrongHostBadSSL", testWrongHostBadSSL),
        ]
    }
}