Swift SDK for Satori RTM
------------------------

RTM is the realtime messaging service at the core of the
[Satori platform](https://www.satori.com).

Swift SDK makes it more convenient to use Satori RTM
from [Swift programming language](https://www.swift.org/about).
Swift version 3 or 4 is required.

Platform compatibility
----------------------

- [x] macOS >= 10.12
- [x] iOS >= 10

Running tests
-------------

Almost all tests are run against real Satori RTM service. The tests require
`credentials.json` file to be populated with RTM credentials. It must include
the following key-value pairs:

```json
{
  "endpoint": "YOUR_ENDPOINT",
  "appkey": "YOUR_APPKEY",
  "auth_role_name": "YOUR_ROLE",
  "auth_role_secret_key": "YOUR_SECRET",
  "auth_restricted_channel": "YOUR_RESTRICTED_CHANNEL"
}
```

* `endpoint` is your customer-specific DNS name for RTM access.
* `appkey` is your application key.
* `auth_role_name` is a role name that permits publishing / subscribing to `auth_restricted_channel`. Must be not `default`.
* `auth_role_secret_key` is a secret key for `auth_role_name`.
* `auth_restricted_channel` is a channel with subscribe and publish access for `auth_role_name` role only.

You must use [Dev Portal](https://developer.satori.com/) to create the role and set channel permissions.

After setting up `credentials.json`, run SDK tests with the following commands:

```bash
swift test
```

Installation
------------

## Swift Package Manager

Add the following dependency in your `Package.swift`:

```swift
    .Package(url: "https://github.com/satori-com/satori-rtm-sdk-swift.git", Version(0,1,5)),
```

## Carthage

Not available yet

## Cocoapods

Example Podfile:

```
platform :ios, '10.0'
use_frameworks!

target 'SatoriSubscriberExample' do
  pod 'SatoriRTM', :git => "https://github.com/satori-com/satori-rtm-sdk-swift.git"
end
```

Getting started
---------------

Please find the examples in the Github repo: https://github.com/satori-com/satori-rtm-sdk-swift/tree/master/Examples
