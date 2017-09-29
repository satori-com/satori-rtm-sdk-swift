import SatoriRTM
import Dispatch
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"
let role = "YOUR_ROLE"
let role_secret_key = "YOUR_SECRET"

let channel = "animals"

let should_authenticate = (role != "YOUR_ROLE")
let authProvider = should_authenticate
    ? RTMAuthProvider.RoleSecretAuthProvider(role: role, secret: role_secret_key)
    : RTMAuthProvider.NoAuthProvider;

print("RTM client config:")
print("\tendpoint =", endpoint)
print("\tappkey =", appkey)
if should_authenticate {
    print("\tauthenticate? = true (as \(role))")
} else {
    print("\tauthenticate? = false")
}

struct Animal {
    let who_: String
    let where_: [Double]
    init(dictionary: [String: Any]) {
        who_ = dictionary["who"] as! String
        where_ = dictionary["where"] as! [Double]
    }
}

var client = RTMClient(endpoint: endpoint, appkey: appkey, authProvider: authProvider, callbackQueue: DispatchQueue.main)

client.on({ (_, event) in
    switch event {
    case let .Disconnected(error):
        print("Disconnected from RTM: \(error)")
        exit(1)
    case let .FailedToConnect(error):
        print("Connecting to Satori RTM failed: \(error)")
        exit(1)
    case .Connected:
        print("Connected to RTM!")
        client.subscribe(config: RTMSubscriptionConfig(channel: channel)) { _, subEvent in
            switch subEvent {
            case .Data(_, let messages, _):
                for message in messages {
                    let a = Animal(dictionary: message as! [String : Any])
                    print("Got animal \(a)")
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
            }
        }
    default:
        ()
    }
})

client.start()

print("\nPress CTRL-C to exit\n")

let coords = [34.134358, -118.321506]
let animal: [String : Any] = ["who": "zebra", "where": coords]

Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
    client.publish(channel: channel, message: animal) { pubResult in
        switch pubResult {
            case let .SolicitedError(code: code, reason: reason):
                print("Publishing failed, code: \(code), reason: \(reason)")
                exit(1)
            case .Disconnect(reason: let reason):
                print("Publishing failed due to a disconnect: \(reason)")
                exit(1)
            default:
                ()
        }
    }
}

RunLoop.current.run()