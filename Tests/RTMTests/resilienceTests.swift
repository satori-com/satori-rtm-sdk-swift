import XCTest
import SatoriRTM

class resilienceTests: XCTestCase {
    override func setUp() {
        RTMEnableLogging()
    }

    func testReconnect() {
        var connectedCounter = 0
        let exp = XCTestExpectation()
        let client = RTMClient(endpoint: rtm_endpoint, appkey: rtm_appkey, authProvider: .NoAuthProvider, callbackQueue: DispatchQueue.main)
        client.enableAutomaticReconnects()
        client.on({ (_, event) in
            switch event {
            case .Connected:
                connectedCounter += 1
                print("connectedCounter: \(connectedCounter)")
                switch connectedCounter {
                case 1:
                    client.emulateDisconnect()
                default:
                    exp.fulfill()
                }
            default:
                ()
            }
        })

        client.start()
        wait(for: [exp], timeout: 10.0)
    }

    static var allTests : [(String, (resilienceTests) -> () throws -> Void)] {
        return [
            // TODO: collect all these automatically somehow
            ("testReconnect", testReconnect),
        ]
    }
}