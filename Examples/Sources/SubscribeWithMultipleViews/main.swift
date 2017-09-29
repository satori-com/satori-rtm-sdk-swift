import SatoriRTM
import Darwin
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"

var client = RTMClient(endpoint: endpoint, appkey: appkey, authProvider: .NoAuthProvider, callbackQueue: DispatchQueue.main)

struct Animal {
    let who_: String
    let where_: [Double]
    init(dictionary: [String: Any]) {
        who_ = dictionary["who"] as! String
        where_ = dictionary["where"] as! [Double]
    }
}

print("Connected to Satori RTM!")

func onEvent(_ onMessage: @escaping (Message) -> ()) -> ((RTMClient, RTMSubscriptionEvent) -> ()) {
    return { (_, event) in
    switch event {
    case .Data(_, let messages, _):
        for message in messages {
            onMessage(message)
        }
    case let .Error(code: code, reason: reason):
        print("Subscription error, code: \(code), reason: \(reason)")
    default:
        ()
    }}
}

client.on({ (_, event) in
    switch event {
    case .Connected:
        print("Connected to Satori RTM!")

        let zebrasConfig = RTMSubscriptionConfig(subscriptionId: "zebras", view: "select * from `animals` where `who` = 'zebra'")
        client.subscribe(config: zebrasConfig, onEvent: onEvent({message in 
                let a = Animal(dictionary: message as! [String : Any])
                print("Got animal \(a)")
            }))

        let countConfig = RTMSubscriptionConfig(subscriptionId: "count", view: "select count(*) as count from `animals` group by who")
        client.subscribe(config: countConfig, onEvent: onEvent({message in
                print("Got count message \(message)")
            }))

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