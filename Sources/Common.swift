import Foundation

import SwiftyBeaver

internal let satorilog = SwiftyBeaver.self

public typealias Action = String
public typealias PDUBody = [String : Any]
public typealias Message = Any
public typealias SubscriptionId = String
public typealias Position = String
public typealias AckId = Int64
public typealias PDU = (Action, PDUBody?, AckId?)

/**
 RTMSolicitedResult represents a result of an RTM request such as rtm/subscribe or rtm/write.
 */
public enum RTMSolicitedResult {
    /// rtm/<action>/ok arrived
    case SolicitedOK(body: PDUBody?)

    /// rtm/<action>/error arrived
    case SolicitedError(code: String, reason: String)

    /// A disconnect happened before the reply had a chance to arrive
    case Disconnect(reason: Error?)
}
public typealias Callback = (RTMSolicitedResult) -> ()

/// Enable debug logging to the console
public func RTMEnableLogging() {
    struct S {
        static var loggingAlreadyEnabled: Bool = false
    }
    if not(S.loggingAlreadyEnabled) {
        satorilog.addDestination(ConsoleDestination())
        S.loggingAlreadyEnabled = true
    }
}