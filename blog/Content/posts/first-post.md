---
date: 2022-08-07 18:32
description: A description of my first post.
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
