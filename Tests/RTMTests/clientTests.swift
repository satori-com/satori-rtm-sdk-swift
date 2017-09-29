import XCTest
import SatoriRTM

class clientTests: XCTestCase {
    override func setUp() {
        RTMEnableLogging()
    }

    func boilerplate(_ f: @escaping (RTMClient, XCTestExpectation, String) -> (), authProvider: RTMAuthProvider = .NoAuthProvider) {
        let client = RTMClient(endpoint: rtm_endpoint, appkey: rtm_appkey, authProvider: authProvider, callbackQueue: DispatchQueue.main)
        let exp = XCTestExpectation()
        let channel = makeChannel()

        client.on({ (_, event) in
            switch event {
            case .Connected:
                f(client, exp, channel)
            default:
                ()
            }
        })

        client.start()
        wait(for: [exp], timeout: 10.0)
        client.stop()
    }

    func testPublishError() {
        self.boilerplate({(client, exp, _) in
            client.publish(channel: "", message: "") { ack in
                switch ack {
                case let .SolicitedError(code: code, reason: _):
                    XCTAssertEqual(code, "invalid_format")
                default:
                    fatalError("Expected publish error")
                }
                exp.fulfill()
            }
        })
    }

    func testPublishAuthError() {
        self.boilerplate({(client, exp, _) in
            client.publish(channel: rtm_restricted_channel, message: "") { ack in
                switch ack {
                case let .SolicitedError(code: code, reason: _):
                    XCTAssertEqual(code, "authorization_denied")
                default:
                    fatalError("Expected publish error")
                }
                exp.fulfill()
            }
        })
    }

    func testPublishOK() {
        self.boilerplate({(client, exp, channel) in
            client.publish(channel: channel, message: "foo") { ack in
                switch ack {
                case .SolicitedOK(_):
                    ()
                default:
                    XCTAssert(false)
                }
                exp.fulfill()
            }
        })
    }

    func testAuthPublishOK() {
        self.boilerplate({(client, exp, _) in
            client.publish(channel: rtm_restricted_channel, message: "foo") { ack in
                switch ack {
                case .SolicitedOK(_):
                    ()
                default:
                    XCTAssert(false)
                }
                exp.fulfill()
            }
        }, authProvider: .RoleSecretAuthProvider(role: rtm_role, secret: rtm_role_secret))
    }

    func testAuthError() {
        let queue = DispatchQueue.main
        let client = RTMClient(
            endpoint: rtm_endpoint,
            appkey: rtm_appkey,
            authProvider: .RoleSecretAuthProvider(role: rtm_role, secret: "wrong_secret"),
            callbackQueue: queue)

        let exp = XCTestExpectation()
        client.on({ (_, event) in
            switch event {
            case .FailedToConnect(RTMClientError.AuthenticationFailed(_)):
                exp.fulfill()
            default:
                XCTAssertFalse(true, "Expected auth error but got: \(event)")
                exp.fulfill()
            }
        })

        client.start()
        wait(for: [exp], timeout: 10.0)
        client.stop()
    }

    func testSubscribe() {
        let basicMessages: [Any] =
            [42, 3.1415, "hello", true, false, [], [:], "", "Сообщение"]
        let dictMessages: [[String : Any]] = basicMessages.map { ["key": $0] }

        func helper(_ makeConfig: @escaping (String) -> RTMSubscriptionConfig) {
            self.boilerplate({(client, exp, channel) in
                var gotMessages = [Any]()

                client.subscribe(config: makeConfig(channel)) {_, event in
                    switch event {
                    case .Data(_, let messages, _):
                        for m in messages {
                            gotMessages.append(m)
                        }
                        if (gotMessages.count == dictMessages.count) {
                            for i in (0..<gotMessages.count) {
                                let expectedMsg = dictMessages[i]
                                let msg = gotMessages[i]
                                let expectedJSON = try! JSONSerialization.data(withJSONObject: expectedMsg)
                                let gotJSON = try! JSONSerialization.data(withJSONObject: msg)
                                XCTAssertEqual(expectedJSON, gotJSON)
                            }
                            exp.fulfill()
                        }
                    case .Subscribed:
                        for message in dictMessages {
                            client.publish(channel: channel, message: message) {_ in ()}
                        }
                    default:
                        ()
                    }}
            })
        }

        helper({channel in RTMSubscriptionConfig(view: "select * from `\(channel)`")})
        helper({channel in RTMSubscriptionConfig(channel: channel)})
        helper({channel in RTMSubscriptionConfig(subscriptionId: channel, view: "select * from `\(channel)`")})
    }

    func testHistoricSubscribe() {
        func helper(_ makeConfig: @escaping (String, String, Int) -> RTMSubscriptionConfig) {
            self.boilerplate({(client, exp, channel) in
                let view = "select * from `\(channel)`"
                var gotMessages = [Any]()

                var position = ""
                let messages: [[String : Int]] = (1 ... 5).map({["x": $0]})

                client.publish(channel: channel, message: "primer") {result in
                    switch result {
                    case .SolicitedOK(let body):
                        position = body!["position"] as! String
                    default:
                        fatalError("publishing the primer failed")
                    }
                }

                for m in messages {
                    client.publish(channel: channel, message: m) {_ in ()}
                }

                client.publish(channel: channel, message: "finisher") {result in
                    client.subscribe(config: makeConfig(view, position, messages.count)) {(currentClient, event) in
                        switch event {
                        case .Data(_, let messages, _):
                            for m in messages {
                                gotMessages.append(m)
                            }
                            if (gotMessages.count == messages.count) {
                                for i in (0..<gotMessages.count) {
                                    let expectedMsg = messages[i]
                                    let msg = gotMessages[i]
                                    let expectedJSON = try! JSONSerialization.data(withJSONObject: expectedMsg)
                                    let gotJSON = try! JSONSerialization.data(withJSONObject: msg)
                                    XCTAssertEqual(expectedJSON, gotJSON)
                                }
                                exp.fulfill()
                            }
                        default:
                            ()
                        }
                    }
                }
            })
        }
        helper({(chan, _pos, _count) in RTMSubscriptionConfig(view: chan, age: 10)})
        helper({(chan, _pos, count) in RTMSubscriptionConfig(view: chan, count: count)})
        helper({(chan, pos, _count) in RTMSubscriptionConfig(view: chan, position: pos)})
    }

    func testDoubleSubscribe() {
        self.boilerplate({(client, exp, channel) in
            client.when_subscribed(config: RTMSubscriptionConfig(channel: channel)) {
                client.subscribe(config: RTMSubscriptionConfig(channel: channel)) { (_, event) in
                    switch event {
                    case .FailedToSubscribe(code: let code, reason: _):
                        XCTAssertEqual(code, "already_subscribed")
                    default:
                        XCTAssertFalse(true, "Expected to get already_subscribed error but got \(event)")
                    }
                    exp.fulfill()
                }
            }
        })
    }

    func testSubscribeAuthError() {
        self.boilerplate({(client, exp, _) in
            let config = RTMSubscriptionConfig(channel: rtm_restricted_channel)
            client.subscribe(config: config) { (_, event) in
                switch event {
                case .FailedToSubscribe(_):
                    exp.fulfill()
                default:
                    ()
                }
            }
        })
    }

    func testUnsubscribeSubscribe() {
        self.boilerplate({(client, exp, channel) in
            let view = "select * from `\(channel)`"
            let config = RTMSubscriptionConfig(view: view)
            var gotMessages = [[String : String]]()
            func onEvent(_ client: RTMClient, event: RTMSubscriptionEvent) {
                switch event {
                case .Subscribed:
                    client.publish(channel: channel, message: ["text": "message"]) { _ in () }
                case .Data(_, messages: let messages, _):
                    for m in messages {
                        gotMessages.append(m as! [String : String])
                    }
                    if (gotMessages.count == 2) {
                        XCTAssertEqual(gotMessages[0], ["text": "message"])
                        XCTAssertEqual(gotMessages[1], ["text": "message"])
                        exp.fulfill()
                    } else {
                        client.unsubscribe(subscriptionId: view)
                    }
                case .Unsubscribed:
                    client.publish(channel: channel, message: "should be missed") { _ in
                        client.subscribe(config: config, onEvent: onEvent)
                    }
                default:
                    ()
                }
            }
            client.subscribe(config: config, onEvent: onEvent)
        })
    }

    func testUnsubscribeError() {
        self.boilerplate({(client, exp, channel) in
            client.unsubscribe(subscriptionId: channel) { result in
                switch result {
                case .SolicitedError(code: "not_subscribed", reason: "Not subscribed to \(channel)"):
                    ()
                default:
                    XCTAssertFalse(true, "Unexpected unsubscribe result: \(result)")
                }
                exp.fulfill()
            }
        })
    }

    func testKV() {
        self.boilerplate({(client, exp, channel) in
            let message = makeChannel()
            client.read(channel: channel) { result in
                XCTAssertNotNil(getBody(result)["message"] as? NSNull)
                client.write(channel: channel, message: message) { _ in
                    client.read(channel: channel) { result in
                        XCTAssertNotNil(getBody(result)["message"] as? String, message)
                        client.delete(channel: channel) { _ in
                            client.read(channel: channel) { result in
                                XCTAssertNotNil(getBody(result)["message"] as? NSNull)
                                exp.fulfill()
                            }
                        }
                    }
                }
            }
        })
    }

    func testPing() {
        let client = RTMClient(endpoint: rtm_endpoint, appkey: rtm_appkey, callbackQueue: DispatchQueue.main)
        let exp = XCTestExpectation()

        client.on({ (_, event) in
            switch event {
            case .Connected:
                try! client.ping()
            case .Ponged:
                exp.fulfill()
            default:
                ()
            }
        })

        client.start()
        wait(for: [exp], timeout: 10.0)
        client.stop()
    }

    func testDisconnectedClient() {
        let queue = DispatchQueue.main
        let client = RTMClient(endpoint: rtm_endpoint, appkey: rtm_appkey, authProvider: .NoAuthProvider, callbackQueue: queue)
        let channel = makeChannel()
        let message = makeChannel()
        func assertRaises(_ msg: String, _ f: () throws -> Any) {
            do {
                _ = try f()
                XCTAssertFalse(true, msg)
            } catch {
                switch(error) {
                case RTMClientError.Disconnected:
                    ()
                default:
                    print("Unexpected error:", error, msg)
                    XCTAssertFalse(true, msg)
                }
            }
        }
        assertRaises("ping", {try client.ping()})
        func check(_ result: RTMSolicitedResult, _ msg: String) {
            switch result {
            case .Disconnect(nil):
                ()
            default:
                XCTAssertFalse(true, msg)
            }
        }
        client.publish(channel: channel, message: message) { check($0, "publish") }
        client.write(channel: channel, message: message) { check($0, "write") }
        client.read(channel: channel) { check($0, "read") }
        client.delete(channel: channel) { check($0, "delete") }
    }

    static var allTests : [(String, (clientTests) -> () throws -> Void)] {
        return [
            // TODO: collect all these automatically somehow
            ("testPublishError", testPublishError),
            ("testPublishAuthError", testPublishAuthError),
            ("testPublishOK", testPublishOK),
            ("testAuthPublishOK", testAuthPublishOK),
            ("testAuthError", testAuthError),
            ("testSubscribe", testSubscribe),
            ("testDoubleSubscribe", testDoubleSubscribe),
            ("testKV", testKV),
            ("testPing", testPing),
            ("testDisconnectedClient", testDisconnectedClient),
        ]
    }
}