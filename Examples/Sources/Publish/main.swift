import SatoriRTM
import Darwin
import Dispatch
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"

var client = RTMClient(endpoint: endpoint, appkey: appkey, authProvider: .NoAuthProvider, callbackQueue: DispatchQueue.main)

let message: Any = ["who": "owl", "where": [11.11, 22.22]]

func publish_loop() {
    client.publish(channel: "animals", message: message) { result in
        switch(result) {
        case let .Disconnect(maybeReason):
            print("Disconnected while waiting for publish reply")
            if let reason = maybeReason {
                print("Reason: \(reason)")
            }
            exit(1)
        case .SolicitedOK(_):
            print("Publish complete")
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                publish_loop()
            }
        case let .SolicitedError(code: code, reason: reason):
            print("Publish failed, code: \(code), reason: \(reason)")
            exit(1)
        }
    }
}

client.on({ (_, event) in
    switch event {
    case .Connected:
        print("Connected to Satori RTM!")
        publish_loop()
    case .FailedToConnect(let error):
        print("Connecting to Satori RTM failed:", error)
        exit(1)
    default:
        ()
    }
})

client.start()
defer { client.stop() }

RunLoop.current.run()