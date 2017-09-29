import Foundation
import Starscream
import CommonCrypto
import Dispatch

/**
  RTMSubscriptionConfig holds the arguments for a subscription request.

  See https://www.satori.com/docs/using-satori/rtm-api#subscribe-pdu.
*/
public struct RTMSubscriptionConfig {
    enum ChannelOrView {
        case Channel(String)
        case View(String)
    }
    let channelOrView: ChannelOrView
    let subscriptionId: String
    let age: Int?
    let count: Int?
    let fastForward: Bool
    let useLastSeenPositionWhenResubscribing: Bool
    var position: String?

    /**
        Create a RTMSubscriptionConfig for a single channel subscription.
        Underlying subscription_id will be equal to given channel name.

        Position, age, count and fastForward are optional.
    */
    public init(channel: String, position: String? = nil, age: Int? = nil, count: Int? = nil, fastForward: Bool = false, useLastSeenPositionWhenResubscribing: Bool = false) {
        self.channelOrView = .Channel(channel)
        self.subscriptionId = channel
        self.position = position
        self.age = age
        self.count = count
        self.fastForward = fastForward
        self.useLastSeenPositionWhenResubscribing = useLastSeenPositionWhenResubscribing
    }

    /**
        Create a RTMSubscriptionConfig for a view.
        Underlying subscription_id will be equal to given view string.

        Position, age, count and fastForward are optional.
    */
    public init(view: String, position: String? = nil, age: Int? = nil, count: Int? = nil, fastForward: Bool = false, useLastSeenPositionWhenResubscribing: Bool = false) {
        self.channelOrView = .View(view)
        self.subscriptionId = view
        self.position = position
        self.age = age
        self.count = count
        self.fastForward = fastForward
        self.useLastSeenPositionWhenResubscribing = useLastSeenPositionWhenResubscribing
    }

    /**
        Create a RTMSubscriptionConfig for a view with explicit subscription_id.

        Position, age, count and fastForward are optional.
    */
    public init(subscriptionId: String, view: String, position: String? = nil, age: Int? = nil, count: Int? = nil, fastForward: Bool = false, useLastSeenPositionWhenResubscribing: Bool = false) {
        self.channelOrView = .View(view)
        self.subscriptionId = subscriptionId
        self.position = position
        self.age = age
        self.count = count
        self.fastForward = fastForward
        self.useLastSeenPositionWhenResubscribing = useLastSeenPositionWhenResubscribing
    }
}

/**
 RTMSubscriptionEvent describes everything that might happen with a subscription.
 */
public enum RTMSubscriptionEvent {
    /// rtm/subscription/data arrived
    case Data(subscriptionId: SubscriptionId, messages: [Message], position: Position)

    /// rtm/subscription/info arrived
    case Info(pdu: PDU)

    /// rtm/subscription/error arrived
    case Error(code: String, reason: String)

    /// rtm/subscribe/ok arrived
    case Subscribed(position: Position)

    /// rtm/unsubscribe/ok arrived
    case Unsubscribed

    /// rtm/subscribe/error arrived
    case FailedToSubscribe(code: String, reason: String)
}

/**
 RTMAuthProvider is given to RTMClient constructor to specify authentication scheme.
 */
public enum RTMAuthProvider {
    /// Authenticate with role and secret
    case RoleSecretAuthProvider(role: String, secret: String)
    /// Perform no additional authentication, use the `default` role
    case NoAuthProvider
}

/**
 RTMClientError is an enum of errors that can be thrown by RTMClient methods
 */
public enum RTMClientError: Error {
    /// Method failed because of underlying websocket disconnect
    case Disconnected
    /// RTMClient constructor was able to connect, but authentication failed
    case AuthenticationFailed(reason: String)
    /// An error in unsubscribe method
    case Unsubscribe(reason: String)
    /// An error in subscribe method
    case Subscribe(reason: String)
}

internal struct SubscriptionState {
    var position: Position
    let config: RTMSubscriptionConfig
    let onEvent: (RTMClient, RTMSubscriptionEvent) -> ()
}

public enum RTMClientEvent {
    case Disconnected(error: Error?)
    case Connected
    case Ponged
    case FailedToConnect(error: Error)
    case GeneralError(code: String, reason: String)
}

/// RTMClient object represents a connection to Satori RTM service
public class RTMClient {
    let _endpoint: String
    let _appkey: String
    let _authProvider: RTMAuthProvider
    var _connection: RTMConnectionWithPDURouting?
    var _subscriptions: [String : SubscriptionState] = [:]
    var _observers = [(RTMClient, RTMClientEvent) -> ()]()
    let _queue: DispatchQueue

    public func on(_ observer: @escaping (RTMClient, RTMClientEvent) -> ()) {
        _observers.append(observer)
    }

    private func notify(_ event: RTMClientEvent) {
        for observer in _observers {
            observer(self, event)
        }
    }

    /// Construct a new client
    ///
    /// All callbacks (completion blocks of RTMClient's methods and subscription event block) will be called on callbackQueue.
    /// Be sure that client code constructs and interacts with RTMClient instance in the same queue.
    /// Calling RTMClient methods from some other queues will likely result in a data race.
    /// Thread Sanitizer tool in XCode is very helpful for detecting those, don't hesitate to use it.
    public init(endpoint: String, appkey: String, authProvider: RTMAuthProvider = .NoAuthProvider, callbackQueue: DispatchQueue = .main) {
        _endpoint = endpoint
        _appkey = appkey
        _authProvider = authProvider
        _connection = nil
        _queue = callbackQueue
    }

    /**
     Start a client. To be notified about the moment when the connection is established and authentication (if any) is performed,
     use client.on() method and watch for RTMClientEvent.Connected.
     */
    public func start() {
        let conn =  RTMConnectionWithPDURouting(endpoint: _endpoint, appkey: _appkey, callbackQueue: _queue)
        _connection = conn
        conn.onDisconnect = {error in
            if let e = error {
                satorilog.info("Disconnected from Satori RTM, reason: \(e)")
            } else {
                satorilog.info("Disconnected from Satori RTM")
            }
            self.notify(.Disconnected(error: error))
        }
        conn.onPong = { _ in self.notify(.Ponged) }
        conn.onUnsolicitedPDU = {pdu in
            satorilog.debug("onUnsolicitedPDU: \(pdu)")
            let (action, mbody, _) = pdu

            if action == "rtm/subscription/data" {
                guard let body = mbody else {
                    satorilog.error("Subscription data PDU has no body: \(pdu)")
                    conn.close()
                    return
                }

                guard let messages = body["messages"] as? [Message] else {
                    satorilog.error("Subscription data PDU body has no messages: \(pdu)")
                    conn.close()
                    return
                }

                guard let subId = body["subscription_id"] as? SubscriptionId else {
                    satorilog.error("Subscription data PDU body has no subscription id: \(pdu)")
                    conn.close()
                    return
                }

                guard let position = body["position"] as? Position else {
                    satorilog.error("Subscription data PDU body has no position: \(pdu)")
                    conn.close()
                    return
                }

                if var subState = self._subscriptions[subId] {
                    subState.position = position
                    subState.onEvent(self, .Data(subscriptionId: subId, messages: messages, position: position))
                } else {
                    satorilog.warning("Subscription for id \(subId) not found")
                }
            }
        }
        _connection = conn
        conn.connect { error in
            if let err = error {
                self.notify(.FailedToConnect(error: err))
                return
            }

            switch self._authProvider {
            case .NoAuthProvider:
                self.notify(.Connected)
                return
            case let .RoleSecretAuthProvider(role, secret):
                satorilog.debug("Authenticating as \(role)")

                self.authenticate(role, secret) { error in
                    if let err = error {
                        self.notify(.FailedToConnect(error: err))
                        return
                    }

                    self._subscriptions = [:]

                    self.notify(.Connected)
                    return
                }
            }
        }
    }

    /// Stop the client. A stopped client can be restarted (authentication will be restored, but not subscriptions).
    public func stop() {
        _connection?.onDisconnect = nil
        _connection?.onUnsolicitedPDU = nil
        _connection?.close()
    }

    /// Perform rtm/subscribe request
    public func subscribe(
            config: RTMSubscriptionConfig,
            onEvent: @escaping (RTMClient, RTMSubscriptionEvent) -> ()
            ) {

        var history = [String : Any]()
        if let age = config.age {
            history["age"] = age
        }
        if let count = config.count {
            history["count"] = count
        }

        var body = history.isEmpty ? [String : Any]() : ["history": history as Any]

        if let position = config.position {
            body["position"] = position
        }
        if config.fastForward {
            body["fast_forward"] = true
        }

        var subId: String = ""
        switch config.channelOrView {
        case let .Channel(channel):
            body["channel"] = channel
            subId = channel
        case let .View(view):
            subId = config.subscriptionId
            body["subscription_id"] = subId
            body["filter"] = view
        }

        guard let conn = _connection else {
            onEvent(self, .FailedToSubscribe(code: "disconnect", reason: "Not connected"))
            return
        }

        conn.action("rtm/subscribe", body: body) { result in
            switch result {
            case let .SolicitedOK(body):
                guard let position = body?["position"] as? String else {
                    satorilog.error("Got rtm/subscribe/ok without a position")
                    conn.close()
                    return
                }
                self._subscriptions[subId] = SubscriptionState(position: position, config: config, onEvent: onEvent)
                onEvent(self, .Subscribed(position: position))
            case let .SolicitedError(code: code, reason: reason):
                onEvent(self, .FailedToSubscribe(code: code, reason: reason))
            case let .Disconnect(reason: maybeReason):
                var reason = "Disconnect"
                if let realReason = maybeReason {
                    reason = "\(realReason)"
                }
                onEvent(self, .FailedToSubscribe(code: "disconnect", reason: reason))
            }
        }
    }

    /// Perform rtm/unsubscribe request
    public func unsubscribe(subscriptionId: String, completion: Callback? = nil) {
        if not(self._subscriptions.keys.contains(subscriptionId)) {
            completion?(.SolicitedError(code: "not_subscribed", reason: "Not subscribed to \(subscriptionId)"))
        }
        self.action("rtm/unsubscribe", ["subscription_id": subscriptionId]) { result in
            guard let subState = self._subscriptions[subscriptionId] else { return }
            self._subscriptions.removeValue(forKey: subscriptionId)
            subState.onEvent(self, .Unsubscribed)
            completion?(result)
        }
    }

    private func action(_ name: String, _ body: PDUBody, _ callback: Callback? = nil) {
        if let conn = _connection {
            conn.action(name, body: body, callback: callback)
        } else {
            callback?(.Disconnect(reason: nil))
        }
    }

    /// Perform rtm/publish request
    public func publish(channel: String, message: Message, callback: Callback? = nil) {
        self.action("rtm/publish", ["channel": channel, "message": message], callback)
    }

    /// Perform rtm/write request
    public func write(channel: String, message: Message, callback: Callback? = nil) {
        self.action("rtm/write", ["channel": channel, "message": message], callback)
    }

    /// Perform rtm/read request
    public func read(channel: String, callback: Callback? = nil) {
        self.action("rtm/read", ["channel": channel], callback)
    }

    /// Perform rtm/delete request
    public func delete(channel: String, callback: Callback? = nil) {
        self.action("rtm/delete", ["channel": channel], callback)
    }

    private func authenticate(_ role: String, _ secret: String, completion: @escaping (Error?) -> ()) {
        let handshakeBody: [String : Any] =
            [ "method": "role_secret"
            , "data": ["role": role]
            ]
        _connection?.action("auth/handshake", body: handshakeBody) {handshake_ack in
            guard case let .SolicitedOK(body: h_mbody) = handshake_ack
            else {
                switch (handshake_ack) {
                    case let .SolicitedError(code: code, reason: reason):
                        completion(RTMClientError.AuthenticationFailed(reason: "auth/handshake failed, code: \(code), reason: \(reason)"))
                    default:
                        completion(RTMClientError.Disconnected)
                }
                return
            }

            guard
                let body = h_mbody,
                let bodyData = body["data"] as? [String : String],
                let nonce = bodyData["nonce"]
            else {
               completion(RTMClientError.AuthenticationFailed(reason: "no nonce in \(String(describing: h_mbody))"))
               return
            }

            satorilog.debug("nonce \(nonce)")

            let hash = hmac_md5(nonce, secret)

            satorilog.debug("hash \(hash)")

            let authenticateBody: [String : Any] =
                [ "method": "role_secret"
                , "credentials": ["hash": hash]
                ]
            self._connection?.action("auth/authenticate", body: authenticateBody) {authenticate_result in
                guard case .SolicitedOK(_) = authenticate_result
                else {
                    switch (authenticate_result) {
                        case let .SolicitedError(code: code, reason: reason):
                            completion(RTMClientError.AuthenticationFailed(reason: "rtm/authenticate failed, code: \(code), reason: \(reason)"))
                        default:
                            completion(RTMClientError.Disconnected)
                    }
                    return
                }

                completion(nil)
            }
        }
    }

    /// Send a websocket ping
    public func ping() throws {
        guard let conn = _connection else { throw RTMClientError.Disconnected }
        conn.ping()
    }
}

internal func hmac_md5(_ string: String, _ key: String) -> String {
    let digestLen = Int(CC_MD5_DIGEST_LENGTH)
    let resultBytes = UnsafeMutablePointer<CChar>.allocate(capacity: digestLen)
    defer { resultBytes.deallocate(capacity: digestLen) }
    CCHmac(
        CCHmacAlgorithm(kCCHmacAlgMD5),
        key, key.characters.count,
        string, string.characters.count,
        resultBytes);
    let resultData = Data(bytesNoCopy: resultBytes, count: digestLen, deallocator: .none)
    return resultData.base64EncodedString(options: []);
}
