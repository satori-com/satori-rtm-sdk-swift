// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "examples",
    targets: [
        Target(name: "Authenticate"),
        Target(name: "Connect"),
        Target(name: "Publish"),
        Target(name: "ReplacingSubscription"),
        Target(name: "DisconnectRecovery"),
        Target(name: "SubscribeToChannel"),
        Target(name: "SubscribeToOpenChannel"),
        Target(name: "SubscribeWithAge"),
        Target(name: "SubscribeWithCount"),
        Target(name: "SubscribeWithMultipleViews"),
        Target(name: "SubscribeWithPosition"),
        Target(name: "SubscribeWithView")
    ],
    dependencies: [
        .Package(url: "ssh://git@github.com/satori-com/satori-rtm-sdk-swift.git", Version(0,2,0)),
        ]
)
