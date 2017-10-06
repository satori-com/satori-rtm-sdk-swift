extension RTMClient {
    /**
      Enable automatic reconnections after disconnects. Newly connected client
      retains authentication status but loses subscriptions. See
      https://github.com/satori-com/satori-rtm-sdk-swift/blob/master/Examples/Sources/DisconnectRecovery/main.swift
      for an example of how to resubscribe.
    */
    public func enableAutomaticReconnects() {
        self.on { (client, event) in
            switch event {
                case .Disconnected:
                    client.start()
                default:
                    ()
            }
        }
    }
}