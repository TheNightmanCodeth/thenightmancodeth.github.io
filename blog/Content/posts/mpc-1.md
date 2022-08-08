---
date: 2022-08-07 18:32
description: How I got the multipeer connectivity framework working with SwiftUI 4
tags: swift, swiftUI
---
# Using the Multipeer Connectivity Framework with SwiftUI 4

Welcome to my first SwiftUI tutorial! In this one, I’m going to be demonstrating how to implement a basic Multipeer connectivity app that uses SwiftUI 4, no UIKit needed!

Without further ado, let’s begin!

The basic structure of our app will be as follows:

- A MultipeerSession object to handle pairing and communication with our paired peer
- PairView will show the user a list of available peers and allow them to invite them to a game
- GameView will display the game controls and show the user if they’ve won or lost

The game will be a basic “Rock, Paper, Scissors” game. The users will pair up with each other, then they will be shown three options, rock, paper or scissors. When the user selects a move it will be sent to the opponent’s device, and once the timer is up the result will be shown.

With that basic overview out of the way, let’s dive into some code.

We’ll start by creating the MultipeerSession object. First, we need to import MultipeerConnectivity into our class and inherit NSObject and ObrvableObject.

```swift
class RPSMultipeerSession: NSObject, ObservableObject {
    private let serviceType = "rps-service"
    private var myPeerID: MCPeerID
    
    public let serviceAdvertiser: MCNearbyServiceAdvertiser
    public let serviceBrowser: MCNearbyServiceBrowser
    public let session: MCSession
}
```

Here we create a `serviceType` string that will let other devices scanning for peers know that we are using the `RPS` app and are looking for `RPS` peers only. This string can be anything to distinguish our Multipeer service from others. We then create some instance variables that hold our `MCPeerID`, `MCNearbyServiceAdvertiser`, `MCNearbyServiceBrowser` and `MCSession`. These fields need to be made public so that we can perform operations with them outside of the `RPSMultipeerSession` class.

Inside of our object’s `init()` we will need to assign values to the variables we created above.

```swift
init(username: String) {
    myPeerID = MCPeerID(displayName: username)
        
    session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
    serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
    serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
    super.init()
}
```

In our app, we’ll be allowing users to create a username to make discovery of peers easier. Here, we take the provided username as an argument in the initializer and create a `MCPeerID` from it.

Also inside of the initializer we create:

- session: Used for sending and receiving RPS moves
- serviceAdvertiser: Used for advertising ourself to nearby players
- serviceBrowser: Used for finding available players nearby

And don’t forget to call `super.init()` to call the superclass’ init method!

Next, we need to consider how the data will be received from our peer. Later, we will create a delegate for our `session` object that will receive a `Data` object from our peer that we can then turn into something easier to work with. Since we only really have four options (rock, paper, scissors and none), we will be using an `enum` to make dealing with responses more readable and easier to work with. Something like this, placed inside of the same file as our `RPSMultipeerSession` class, will suffice:

```swift
enum Move: String, CaseIterable, CustomStringConvertible {
    case rock, paper, scissors, unknown
    
    var description : String {
        switch self {
        case .rock: return "Rock"
        case .paper: return "Paper"
        case .scissors: return "Scissors"
        default: return "Thinking"
        }
    }
}
```

Later on we will be using a `String` representation of our `Move` to display an image to our player. By using `CustomStringConvertible` we can reduce the amount of code needed to do just that.

Now that we have our `Move` enum created and usable, we should consider what type of data needs to be made available to our views. We know that our `PairView`, which will allow players to find and pair up with their friends, will need to have access to a list of currently available peers. That same view will need to know when we receive an invite from another player, as well as who that player is. The `GameView` will need to know when we receive a move from our opponent. More than one of our views might find it useful to know whether or not we are currently paired with a player and, lastly, our `PairView` will need to have some way of accepting or denying an invitation from another player.

```swift
@Published var availablePeers: [MCPeerID] = []
@Published var receivedMove: Move = .unknown
@Published var recvdInvite: Bool = false
@Published var recvdInviteFrom: MCPeerID? = nil
@Published var paired: Bool = false
@Published var invitationHandler: ((Bool, MCSession?) -> Void)?
```

All together, we will have six `@Published` properties in our `RPSMultipeerSession`. Making these variables `@Published` makes it so that our views can not only see the the value of the variable, but they can be notified when the values change.

With that out of the way, we need to create some delegates for our `session`, `serviceAdvertiser` and `serviceBrowser`. Let’s start with the longest one, `MCSessionDelegate`.

The session delegate has methods to handle:

- When a peer changes state (connected, disconnected, connecting)
- When we receive `Data` from a peer
- When we receive an `InputStream` from a peer
- When we receive a `Resource` from a peer (with or without progress)
- When we receive a certificate from a peer (authentication)

We are really only concerned with two of these methods: when a peer changes state and when we receive `Data` from a user. Even though that is the case, each of these methods needs to be implemented inside of the delegate.

Swift has a neat feature called `extensions`. If you are unfamiliar, extensions essentially let you add code to any Swift class. One could create an `extension` on the `String` class to perform any kind of operation on a string. `Extension`s are extremely powerful and I highly recommend looking into the details but for now that should be a sufficient introduction to get us going.

To prevent our `RPSMultipeerSession` from getting too big to handle, we will utilize Swift’s `extension` to implement these delegates. We can simply do:

> extension RPSMultipeerSession: MCSessionDelegate

and implement the delegate functions in there, outside of the main class but still in the same file. One could place these delegates into separate files, but I personally chose to keep them all inside of one file.

```swift
extension RPSMultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        log.info("peer \(peerID) didChangeState: \(state.rawValue)")
        switch state {
        case MCSessionState.notConnected:
            // Peer disconnected
            break
        case MCSessionState.connected:
            // Peer connected
            break
        default:
            // Peer connecting or something else
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let string = String(data: data, encoding: .utf8), let move = Move(rawValue: string) {
            // Received move from peer
        } else {
            log.info("didReceive invalid value \(data.count) bytes")
        }
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        log.error("Receiving streams is not supported")
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        log.error("Receiving resources is not supported")
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        log.error("Receiving resources is not supported")
    }
    
    public func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
}
```

Like I said earlier, this is a *big* one. Make sure to use XCode’s autocomplete to get the functions declared.

As you can see, most of the functions simply print a line to the console and don’t actually do anything at all. This is because our app does not support sending or receiving streams or resources. This may change as the tutorial goes along, though (;

We’re not done, yet! If you’re following along with the code you’ve probably noticed that delegate doesn’t actually do anything at all. We need to implement the logic for responding to peer connectivity status changes and receiving data from our opponent. I will go in detail in part 2 on how to handle these events, so for now let’s move on.

Next we will implement the `MCNearbyServiceAdvertiserDelegate`. This one is a lot easier to digest:

```swift
extension RPSMultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        log.error("ServiceAdvertiser didNotStartAdvertisingPeer: \(String(describing: error))")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        log.info("didReceiveInvitationFromPeer \(peerID)")
    }
}
```

The service advertiser has two methods: one is called when the advertiser can’t start advertising for some reason and the other when we receive an invitation from another player. The latter will be implemented, again, in part 2!
Last but not least we need to implement the `MCNearbyServiceBrowserDelegate`.

```swift
extension RPSMultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        //TODO: Tell the user something went wrong and try again
        log.error("ServiceBroser didNotStartBrowsingForPeers: \(String(describing: error))")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        log.info("ServiceBrowser found peer: \(peerID)")
        // Add the peer to the list of available peers
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log.info("ServiceBrowser lost peer: \(peerID)")
        // Remove lost peer from list of available peers
    }
}
```

This delegate has methods that are called when:

- The browser does not start browsing for some reason
- The browser found a nearby peer that is advertising our serviceType
- The browser lost a nearby peer that was advertising our serviceType

Now that we have our delegates setup we can apply them to our `session`, `serviceAdvertiser` and `serviceBrowser`.

```swift
session.delegate = self
serviceAdvertiser.delegate = self
serviceBrowser.delegate = self
                
serviceAdvertiser.startAdvertisingPeer()
serviceBrowser.startBrowsingForPeers()
```

We add this inside of our `init()` after the call to `super.init()`. This assigns the delegates and starts advertising and browsing to/for peers.
We’re almost done, but we can’t forget to tell our advertiser and browser to stop inside of `deinit()`.

```swift
deinit {
    serviceAdvertiser.stopAdvertisingPeer()
    serviceBrowser.stopBrowsingForPeers()
}
```

Now that we have all of this done, our `RPSMultipeerSession.swift` file should look like this:

```swift
//
//  RPSMultipeerSession.swift
//  RPS
//
//  Created by Joe Diragi on 7/28/22.
//

import MultipeerConnectivity
import os

enum Move: String, CaseIterable, CustomStringConvertible {
    case rock, paper, scissors, unknown
    
    var description : String {
        switch self {
        case .rock: return "Rock"
        case .paper: return "Paper"
        case .scissors: return "Scissors"
        default: return "Thinking"
        }
      }
}

class RPSMultipeerSession: NSObject, ObservableObject {
    private let serviceType = "rps-service"
    private var myPeerID: MCPeerID
    
    public let serviceAdvertiser: MCNearbyServiceAdvertiser
    public let serviceBrowser: MCNearbyServiceBrowser
    public let session: MCSession
        
    private let log = Logger()
    
    @Published var availablePeers: [MCPeerID] = []
    @Published var receivedMove: Move = .unknown
    @Published var recvdInvite: Bool = false
    @Published var recvdInviteFrom: MCPeerID? = nil
    @Published var paired: Bool = false
    @Published var invitationHandler: ((Bool, MCSession?) -> Void)?
    
    init(username: String) {
        let peerID = MCPeerID(displayName: username)
        self.myPeerID = peerID
        
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        serviceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        super.init()
        
        session.delegate = self
        serviceAdvertiser.delegate = self
        serviceBrowser.delegate = self
                
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
    }
    
    deinit {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
    }
}

extension RPSMultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        log.info("peer \(peerID) didChangeState: \(state.rawValue)")
        switch state {
        case MCSessionState.notConnected:
            // Peer disconnected
            break
        case MCSessionState.connected:
            // Peer connected
            break
        default:
            // Peer connecting or something else
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let string = String(data: data, encoding: .utf8), let move = Move(rawValue: string) {
            // Received move from peer
        } else {
            log.info("didReceive invalid value \(data.count) bytes")
        }
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        log.error("Receiving streams is not supported")
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        log.error("Receiving resources is not supported")
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        log.error("Receiving resources is not supported")
    }
    
    public func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
}

extension RPSMultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        log.error("ServiceAdvertiser didNotStartAdvertisingPeer: \(String(describing: error))")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        log.info("didReceiveInvitationFromPeer \(peerID)")
    }
}

extension RPSMultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        //TODO: Tell the user something went wrong and try again
        log.error("ServiceBroser didNotStartBrowsingForPeers: \(String(describing: error))")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        log.info("ServiceBrowser found peer: \(peerID)")
        // Add the peer to the list of available peers
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log.info("ServiceBrowser lost peer: \(peerID)")
        // Remove lost peer from list of available peers
    }
}
```

[Don't forget to check out the GitHub repo!](https://github.com/TheNightmanCodeth/RPS)

[Continue to part 2](/mpc-2)