import XCTest
@testable import SatoriRTM

class connectionTests: XCTestCase {
    override func setUp() {
        RTMEnableLogging()
    }

    func testSelfSignedBadSSL() {
        let queue = DispatchQueue.main
        let conn = RTMConnection(endpoint: "wss://self-signed.badssl.com", appkey: rtm_appkey, callbackQueue: queue)

        let exp = XCTestExpectation()
        var err: Error?
        conn.connect() { error in
            err = error
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10.0)
        XCTAssert(err != nil)
        print("Error description:", err!.localizedDescription)
        XCTAssertFalse(conn.isConnected)
    }

    func boilerplate(_ f: @escaping (RTMConnection, XCTestExpectation, String) -> (), queue: DispatchQueue = DispatchQueue.main) {
        let conn = RTMConnection(endpoint: rtm_endpoint, appkey: rtm_appkey, callbackQueue: queue)
        let exp = XCTestExpectation()
        let channel = makeChannel()

        conn.connect() { error in
            XCTAssertNil(error)
            f(conn, exp, channel)
        }

        wait(for: [exp], timeout: 10.0)
        conn.close()
    }

    func testConnectionPublishError() {
        self.boilerplate({ (conn, exp, _) in
            conn.onPDU = { pdu in
                let (action, body, id) = pdu
                XCTAssertEqual(action, "rtm/publish/error")
                XCTAssertEqual(id, 42)
                XCTAssertEqual(body!["error"] as! String, "invalid_format")
                exp.fulfill()
            }
            conn.send(pdu: ("rtm/publish", [:], 42))
        })
    }

    func testConnectionPublishOK() {
        self.boilerplate({ (conn, exp, _) in
            conn.onPDU = { pdu in
                let (action, body, id) = pdu
                XCTAssertEqual(action, "rtm/publish/ok")
                XCTAssertEqual(id, 33)

                let okPosition = body!["position"]!
                print("Publish position:", okPosition)
                exp.fulfill()
            }
            conn.send(pdu: ("rtm/publish", ["channel": makeChannel(), "message": 1], 33))
        })
    }

    func testConnectionPublishErrorOnDedicatedQueue() {
        let queue = DispatchQueue(label: "RTM test queue")

        self.boilerplate({ (conn, exp, _) in
            conn.onPDU = { pdu in
                let (action, body, id) = pdu
                XCTAssertEqual(action, "rtm/publish/error")
                XCTAssertEqual(id, 42)
                XCTAssertEqual(body!["error"] as! String, "invalid_format")
                exp.fulfill()
            }
            conn.send(pdu: ("rtm/publish", [:], 42))
        }, queue: queue)
    }

    func testConnectionPublishOKOnDedicatedQueue() {
        let queue = DispatchQueue(label: "RTM test queue")

        self.boilerplate({ (conn, exp, _) in
            conn.onPDU = { pdu in
                let (action, body, id) = pdu
                XCTAssertEqual(action, "rtm/publish/ok")
                XCTAssertEqual(id, 33)

                let okPosition = body!["position"]!
                print("Publish position:", okPosition)
                exp.fulfill()
            }
            conn.send(pdu: ("rtm/publish", ["channel": makeChannel(), "message": 1], 33))
        }, queue: queue)
    }

    static var allTests : [(String, (connectionTests) -> () throws -> Void)] {
        return [
            ("testSelfSignedBadSSL", testSelfSignedBadSSL),
            ("testConnectionPublishError", testConnectionPublishError),
            ("testConnectionPublishErrorOnDedicatedQueue", testConnectionPublishErrorOnDedicatedQueue),
            ("testConnectionPublishOK", testConnectionPublishOK),
            ("testConnectionPublishOKOnDedicatedQueue", testConnectionPublishOKOnDedicatedQueue),
        ]
    }
}