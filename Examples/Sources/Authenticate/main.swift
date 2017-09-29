import SatoriRTM
import Darwin
import Dispatch
import Foundation

let endpoint = "YOUR_ENDPOINT"
let appkey = "YOUR_APPKEY"
let role = "YOUR_ROLE"
let role_secret_key = "YOUR_SECRET"

let authProvider = RTMAuthProvider.RoleSecretAuthProvider(role: role, secret: role_secret_key)

var client = RTMClient(endpoint: endpoint, appkey: appkey, authProvider: authProvider, callbackQueue: DispatchQueue.main)

client.on({ (_, event) in
    switch event {
    case .Connected:
        print("Connected to Satori RTM and authenticated as \(role)!")
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