import SatoriRTM
import Darwin
import Dispatch
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"

var client = RTMClient(endpoint: endpoint, appkey: appkey, authProvider: .NoAuthProvider, callbackQueue: DispatchQueue.main)

client.on({ (_, event) in
    switch event {
    case .Connected:
        print("Connected to Satori RTM!")
        exit(0)
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