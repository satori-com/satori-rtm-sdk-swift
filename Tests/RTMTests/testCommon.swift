import Foundation

@testable import SatoriRTM

// TODO: sane error reporting for missing or invalid credentials.json
let creds_url: URL = URL(string: "file://" + FileManager.default.currentDirectoryPath + "/credentials.json")!;
let json_creds: Data = try! Data(contentsOf: creds_url)
let rtm_creds = try! JSONSerialization.jsonObject(with: json_creds, options: []) as! [String : String]
let rtm_url: URL = URL(string: rtm_creds["endpoint"]! + "/v2?appkey=" + rtm_creds["appkey"]!)!
let rtm_endpoint: String = rtm_creds["endpoint"]!
let rtm_appkey: String = rtm_creds["appkey"]!
let rtm_role: String = rtm_creds["auth_role_name"]!
let rtm_role_secret: String = rtm_creds["auth_role_secret_key"]!
let rtm_restricted_channel: String = rtm_creds["auth_restricted_channel"]!

func makeChannel() -> String {
    let letters = "abcdefghijklmnopqrstuvwxyz"

    let result: String = (0 ... 7).reduce(String()) { acc, _ in
        let letter_index = arc4random_uniform(26)
        let letter = letters[letters.index(letters.startIndex, offsetBy: Int(letter_index))]
        return acc.appending(String(letter))
    }

    return result
}

extension RTMClient {
    public func when_subscribed(config: RTMSubscriptionConfig, completion: @escaping () -> ()) {
        subscribe(config: config) { (_, event) in
            switch event {
            case .Subscribed:
                completion()
            default:
                ()
            }
        }
    }

    public func emulateDisconnect() {
        self._connection?._connection._ws?.disconnect()
    }
}

func getBody(_ result: RTMSolicitedResult) -> PDUBody {
    switch (result) {
        case let .SolicitedOK(mbody):
            return mbody!
        default:
            fatalError("not a successful result")
    }
}