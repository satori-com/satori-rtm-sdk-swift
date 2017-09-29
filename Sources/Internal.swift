import Foundation

internal func decodePDU(data: Data) -> PDU? {
    do {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] else { return nil }
        guard let action = json["action"] as? String else {
            satorilog.error("decodePDU failed: no action field in \(json)")
            return nil
        }
        let id = json["id"] as? AckId
        let body = json["body"] as? PDUBody
        return (action, body, id)
    } catch {
        satorilog.error("decodePDU failed: \(error)")
    }
    return nil
}

internal func encodePDU(pdu: PDU) -> Data? {
    let (action, mbody, mid) = pdu
    var jsonPDU: [String : Any] = ["action": action]
    if let id = mid {
        jsonPDU["id"] = id
    }
    if let body = mbody {
        jsonPDU["body"] = body
    }
    return try? JSONSerialization.data(withJSONObject: jsonPDU)
}