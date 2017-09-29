import XCTest
@testable import SatoriRTM

class routingConnectionTests: XCTestCase {
    override func setUp() {
        RTMEnableLogging()
    }

    func testRoutingConnection() {
        let conn = RTMConnectionWithPDURouting(endpoint: rtm_endpoint, appkey: rtm_appkey, callbackQueue: DispatchQueue.main)

        let exp = XCTestExpectation()
        let exp2 = XCTestExpectation()

        conn.connect() { error in
            guard error == nil else {
                print("Error:", error!)
                XCTAssert(false)
                return
            }

            var unsolicitedPdu: PDU?
            conn.onUnsolicitedPDU = {
                unsolicitedPdu = $0
            }

            conn.action("rtm/publish", body: [:]) { result in
                switch result {
                case let .SolicitedError(code: code, reason: _):
                    XCTAssertEqual(code, "invalid_format")
                default:
                    fatalError("Expected publish error")
                }
                exp2.fulfill()
            }

            let channel = makeChannel()

            conn.action("rtm/subscribe", body: ["channel": channel]) { subResult in
                conn.action("rtm/publish", body: ["channel": channel, "message": ["who": "zebra"]]) { pubResult in
                    switch unsolicitedPdu {
                        case let .some(action, body, _):
                            XCTAssertEqual(action, "rtm/subscription/data")
                            let messages = body!["messages"] as! [[String : String]]
                            let message = messages[0]
                            XCTAssertEqual(message, ["who": "zebra"])
                        default:
                            XCTAssert(false)
                    }
                    exp.fulfill()
                }
            }
        }

        wait(for: [exp, exp2], timeout: 10.0)
    }

    static var allTests : [(String, (routingConnectionTests) -> () throws -> Void)] {
        return [
            ("testRoutingConnection", testRoutingConnection),
        ]
    }
}