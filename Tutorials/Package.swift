// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "quickstart",
    targets: [
        Target(name: "Quickstart"),
    ],
    dependencies: [
        .Package(url: "ssh://git@github.com/satori-com/satori-rtm-sdk-swift.git", Version(0,2,0)),
        ]
)
