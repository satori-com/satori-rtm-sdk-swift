
extension RTMClient {
    public func enableAutomaticReconnects() {
        self.on({ (client, event) in
            switch event {
                case .Disconnected(_):
                    client.start()
                default:
                    ()
            }
        })
    }
}