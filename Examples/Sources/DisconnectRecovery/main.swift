import SatoriRTM
import Darwin
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"

var client = RTMClient(endpoint: endpoint, appkey: appkey, callbackQueue: DispatchQueue.main)
client.enableAutomaticReconnects()

var lastSeenPosition: String?

func subscribe() {
    var subscriptionConfig = RTMSubscriptionConfig(channel: "animals")
    if let p = lastSeenPosition {
        subscriptionConfig = RTMSubscriptionConfig(channel: "animals", position: p)
    }
    client.subscribe(config: subscriptionConfig) { (_, event) in
        switch event {
        case let .Data(_, messages, position):
            lastSeenPosition = position
            for message in messages {
                print("Got message \(message)")
            }
        case let .Error(code: code, reason: reason):
            print("Subscription error, code: \(code), reason: \(reason)")
        case let .FailedToSubscribe(code: code, reason: reason):
            if code == "out_of_sync" {
                lastSeenPosition = nil
                subscribe()
            } else {
                print("Failed to subscribe, code: \(code), reason: \(reason)")
                exit(1)
            }
        case .Subscribed(_):
            print("Subscribed successfully!")
            return
        default:
            ()
        }
    }
}

client.on({ (_, event) in
    switch event {
    case .Connected:
        print("Connected to Satori RTM!")
        subscribe()
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