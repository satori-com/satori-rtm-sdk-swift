import Foundation
import Starscream

enum RTMConnectionError: Error {
    case malformedCredentials(endpoint: String, appkey: String)
    case protocolError(reason: String)
    case timeout
}

class RTMConnection {
    let _endpoint: String
    let _appkey: String
    let _callbackQueue: DispatchQueue
    var _ws: Starscream.WebSocket?

    var isConnected: Bool
    var onPDU: ((PDU) -> ())?
    var onDisconnect: ((Error?) -> ())?
    var onPong: (() -> ())?

    init(endpoint: String, appkey: String, callbackQueue: DispatchQueue) {
        _endpoint = endpoint
        _appkey = appkey
        _callbackQueue = callbackQueue
        isConnected = false
    }

    func connect(completion: @escaping (Error?) -> ()) {
        precondition(isConnected == false)

        guard let url = URL(string: _endpoint + "/v2?appkey=" + _appkey) else {
            completion(RTMConnectionError.malformedCredentials(endpoint: _endpoint, appkey: _appkey))
            return
        }

        let ws = Starscream.WebSocket(url: url)
        _ws = ws
        ws.callbackQueue = _callbackQueue

        ws.onPong = { _ in self.onPong?() }
        ws.onConnect = {
            self.isConnected = true
            completion(nil)
            ws.onDisconnect = { error in
                self.isConnected = false
                self.onDisconnect?(error)
            }
        }
        ws.onDisconnect = { error in
            completion(error)
        }
        ws.onText = { text in
            satorilog.debug("Incoming text: \(text)")
            if let data: Data = text.data(using: .utf8, allowLossyConversion: false) {
                if let pdu = decodePDU(data: data) {
                    self.onPDU?(pdu)
                } else {
                    let err = "Failed to parse PDU: \(text)"
                    self.onDisconnect?(RTMConnectionError.protocolError(reason: err))
                    self.close()
                }
            } else {
                let err = "Received a text frame that is not UTF8: \(text)"
                self.onDisconnect?(RTMConnectionError.protocolError(reason: err))
                self.close()
            }
        }
        ws.connect()

        return
    }

    func close() {
        isConnected = false

        guard let ws = _ws else { return }

        ws.onConnect = nil
        ws.onDisconnect = nil
        ws.onText = nil
        ws.onData = nil
        ws.onPong = nil
        if ws.isConnected {
            ws.disconnect()
        }
    }

    func send(pdu: PDU) {
        guard let pduData = encodePDU(pdu: pdu) else {
            satorilog.error("encodePDU failed with \(pdu)")
            return
        }

        if let outgoingText = String(data: pduData, encoding: String.Encoding.utf8) {
            satorilog.debug("Outgoing text:", outgoingText)
        }

        _ws?.write(data: pduData)
    }

    func ping() {
        _ws?.write(ping: Data())
    }
}