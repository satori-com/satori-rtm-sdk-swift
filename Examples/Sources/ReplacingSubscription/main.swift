import SatoriRTM
import Darwin
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"

let firstSubscriptionConfig = RTMSubscriptionConfig(channel: "animals")
let secondSubscriptionConfig = RTMSubscriptionConfig(subscriptionId: "animals", view: "select * from `animals`")

var client = RTMClient(endpoint: endpoint, appkey: appkey, callbackQueue: DispatchQueue.main)

client.on({ (_, event) in
    switch event {
    case .Connected:
        print("Connected to Satori RTM!")

        client.subscribe(config: firstSubscriptionConfig) { (_, event) in
            switch event {
            case .Subscribed(_):
                client.unsubscribe(subscriptionId: "animals")
                client.subscribe(config: secondSubscriptionConfig) { (_, event) in
                    switch event { 
                    case .Subscribed(_):
                        print("Subscription replaced")
                    case .Data(_, let messages, _):
                        for message in messages {
                            print("Got message \(message)")
                        }
                    default:
                        ()
                    }
                }
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