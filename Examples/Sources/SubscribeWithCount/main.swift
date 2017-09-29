import SatoriRTM
import Darwin
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"

let subscriptionConfig = RTMSubscriptionConfig(channel: "animals", count: 10)
var client = RTMClient(endpoint: endpoint, appkey: appkey, callbackQueue: DispatchQueue.main)

client.on({ (_, event) in
    switch event {
    case .Connected:
        print("Connected to Satori RTM!")

        client.subscribe(config: subscriptionConfig) { (_, event) in
            switch event {
            case .Data(_, let messages, _):
                for message in messages {
                    print("Got message \(message)")
                }
            case let .Error(code: code, reason: reason):
                print("Subscription error, code: \(code), reason: \(reason)")
                exit(1)
            case let .FailedToSubscribe(code: code, reason: reason):
                print("Failed to subscribe, code: \(code), reason: \(reason)")
                exit(1)
            case .Subscribed(_):
                print("Subscribed successfully!")
                return
            default:
                ()
            }}
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