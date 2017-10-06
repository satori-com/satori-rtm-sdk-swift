import Dispatch
import Foundation

internal class RTMConnectionWithPDURouting {
    let _connection: RTMConnection
    var _nextActionId: AckId = 0
    var _callbackById: [AckId : Callback] = [:]
    var onUnsolicitedPDU: ((PDU) -> ())?
    var onSolicitedPDU: (@escaping Callback, RTMSolicitedResult) -> () = { (callback, result) in callback(result) }
    var onDisconnect: ((Error?) -> ())?
    var onPong: (() -> ())?

    init(endpoint: String, appkey: String, callbackQueue: DispatchQueue) {
        _connection = RTMConnection(endpoint: endpoint, appkey: appkey, callbackQueue: callbackQueue)
    }

    func connect(completion: @escaping (Error?) -> ()) {
        _connection.onDisconnect = {error in
            self.onDisconnect?(error)
        }
        _connection.onPong = { self.onPong?() }
        _connection.onPDU = { pdu in
            let (action, body, mid) = pdu
            if let id = mid {
                if let callback = self._callbackById.removeValue(forKey: id) {
                    let result: RTMSolicitedResult
                    if action.hasSuffix("/ok") {
                        result = .SolicitedOK(body: body)
                    } else {
                        result = .SolicitedError(
                            code: body?["error"] as? String ?? "Unknown error",
                            reason: body?["reason"] as? String ?? "Unknown reason")
                    }
                    self.onSolicitedPDU(callback, result)
                }
                return
            }
            self.onUnsolicitedPDU?(pdu)
        }
        _connection.connect(completion: completion)
    }

    func close() {
        _connection.onPDU = nil
        _callbackById.removeAll(keepingCapacity: false)
        _connection.close()
    }

    func action(_ action: Action, body: PDUBody, callback: Callback?) {
        var pdu: PDU = (action, body, nil)
        if let c = callback {
            let id = _nextActionId
            _nextActionId += 1
            _callbackById[id] = c
            pdu = (action, body, id)
        }
        _connection.send(pdu: pdu)
    }

    func ping() {
        _connection.ping()
    }
}
