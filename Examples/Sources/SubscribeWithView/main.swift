import SatoriRTM
import Darwin
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"

struct Animal {
    let who_: String
    let where_: [Double]
    init(dictionary: [String: Any]) {
        who_ = dictionary["who"] as! String
        where_ = dictionary["where"] as! [Double]
    }
}

var client = RTMClient(endpoint: endpoint, appkey: appkey, authProvider: .NoAuthProvider, callbackQueue: DispatchQueue.main)

client.on({ (_, event) in
    switch event {
    case .Connected:
        print("Connected to Satori RTM!")
        let config = RTMSubscriptionConfig(subscriptionId: "zebras", view: "select * from `animals` where `who` = 'zebra'")
        client.subscribe(config: config) { (_, event) in
            switch event {
            case .Data(_, let messages, _):
                for message in messages {
                    let a = Animal(dictionary: message as! [String : Any])
                    print("Got animal \(a)")
                }
            case let .Error(code: code, reason: reason):
                print("Subscription error, code: \(code), reason: \(reason)")
            default:
                ()
            }
        }
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