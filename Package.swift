// swift-tools-version:3.1
import PackageDescription

let package = Package(
    name: "SatoriRTM",
    targets: [
        Target(name: "SatoriRTM", dependencies: []),
        Target(name: "RTMTests", dependencies: ["SatoriRTM"]),
        ],
    dependencies: [
        .Package(url: "https://github.com/daltoniam/Starscream.git", Version(3,0,0)),
        .Package(url: "https://github.com/IBM-Swift/CommonCrypto.git", majorVersion: 0),
        .Package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", Version(1,4,1)),
        ]
)
