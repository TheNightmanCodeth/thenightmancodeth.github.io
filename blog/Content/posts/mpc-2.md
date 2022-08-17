---
date: 2022-08-07 18:32
description: How I got the multipeer connectivity framework working with SwiftUI 4 - Part 2
tags: swift, swiftUI
---

In (part 1)[/mpc-1] we created a skeleton RPSMultipeerSession to communicate from one device to another directly using only the multipeer connectivity framework, no backend server was used at all.
In this part we will finish implementing those methods and start building the UI!
To start, we need a way to send our move to our opponent. Inside of the RPSMultipeerSession class, after deinit(), we will place this method:

```swift
func send(move: Move) {
    if !session.connectedPeers.isEmpty {
        log.info("sendMove: \(String(describing: move)) to \(self.session.connectedPeers[0].displayName)")
        do {
            try session.send(move.rawValue.data(using: .utf8)!, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            log.error("Error sending: \(String(describing: error))")
        }
    }
}
```

First we ensure our opponent is connected by checking if session.connectedPeers is empty. If it isn't empty, we have an opponent connected and waiting to receive our move. We try and send the move provided using session.send() and catch any exceptions thrown.
With the send method implemented we can move on to finishing up the delegates.
Inside of the MCSessionDelegate, there is a switch statement that handles the state of the peer whose state has changed. If the peer has disconnected, we should make our paired variable false and start looking for another opponent. If the peer has connected, we set our paired variable to true and stop looking for peers. If something else happened, most likely the peer is currently connecting, and therefore our paired variable should be false.
The implementation looks like this:

```swift
switch state {
case MCSessionState.notConnected:
    // Peer disconnected
    DispatchQueue.main.async {
        self.paired = false
    }
    // Peer disconnected, start accepting invitaions again
    serviceAdvertiser.startAdvertisingPeer()
    break
case MCSessionState.connected:
    // Peer connected
    DispatchQueue.main.async {
        self.paired = true
    }
    // We are paired, stop accepting invitations
    serviceAdvertiser.stopAdvertisingPeer()
    break
default:
    // Peer connecting or something else
    DispatchQueue.main.async {
        self.paired = false
    }
    break
}
```

Since paired is a published variable and we will have views listening for changes we need to make our changes on the main thread, hence DispatchQueue.main.async is used.
Still in the MCSessionDelegate, the didReceive data: method is next. When we receive a message from our opponent we should tell the view that we received a move and what that move is. The implementation would look like this:

```swift
func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    if let string = String(data: data, encoding: .utf8), let move = Move(rawValue: string) {
        log.info("didReceive move \(string)")
        // We received a move from the opponent, tell the GameView
        DispatchQueue.main.async {
            self.receivedMove = move
        }
    } else {
        log.info("didReceive invalid value \(data.count) bytes")
    }
}
```

Here we make sure we can create a Move from the data we received and, if we can, we update, on the main thread, the value of receivedMove.
The rest of this delegate can be left the way it is.
Inside of the MCNearbyServiceAdvertiserDelegate, there is one method that needs to be completed. It's the didReceiveInvitationFromPeer one and the implementation looks like this:

```swift
func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    log.info("didReceiveInvitationFromPeer \(peerID)")
    
    DispatchQueue.main.async {
        // Tell PairView to show the invitation alert
        self.recvdInvite = true
        // Give PairView the peerID of the peer who invited us
        self.recvdInviteFrom = peerID
        // Give PairView the `invitationHandler` so it can accept/deny the invitation
        self.invitationHandler = invitationHandler
    }
}
```

When we receive an invitation from another player we want to let our view know so it can prompt our user to accept or reject the invitation. We tell our view we received an invite, who invited us and give it an invitationHandler to respond to the other player with.
Next we will finish up the MCNearbyServiceBrowserDelegate. When the browser finds a peer we want to add it to availablePeers so our view can show it to our user. The implementation looks like this:

```swift
func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    log.info("ServiceBrowser found peer: \(peerID)")
    // Add the peer to the list of available peers
    DispatchQueue.main.async {
        self.availablePeers.append(peerID)
    }
}
```

We simply append the peerID to availablePeers on the main thread. Easy, right?
And our last bit of missing code is inside of the lostPeer browser method. When a peer is lost, it should be removed from availablePeers, like so:

```swift
func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    log.info("ServiceBrowser lost peer: \(peerID)")
    // Remove lost peer from list of available peers
    DispatchQueue.main.async {
        self.availablePeers.removeAll(where: {
            $0 == peerID
        })
    }
}
```

And that wraps up our RPSMultipeerSession! Now we move on to creating the UI and dealing with these data.
In UI land, we need to create a starting view to allow our user to set his/her username. This can be done in many ways, but once the text is received we should use a NavigationLink or similar to move on to the pairing screen.

```swift
NavigationLink(destination: PairView(rpsSession: RPSMultipeerSession(username: username))) {
    Image(systemName: "arrow.right.circle.fill")
        .foregroundColor(Color(.gray))
}
```

This is how I did it, passing the username into the RPSMultipeerSession as an argument for the PairView.
If our session object's paired property is false, the PairView will display a list of buttons with the username of players nearby who are also on the PairView. When the user clicks one of the buttons, an invitation will be sent to that user and an alert will be shown prompting the player to accept or reject the invitation. Here's how that would look:

```swift
import SwiftUI
import os

struct PairView: View {
    @StateObject var rpsSession: RPSMultipeerSession
    var logger = Logger()
        
    var body: some View {
        if (!rpsSession.paired) {
            HStack {
                List(rpsSession.availablePeers, id: \.self) { peer in
                    Button(peer.displayName) {
                        rpsSession.serviceBrowser.invitePeer(peer, to: rpsSession.session, withContext: nil, timeout: 30)
                    }
                }
            }
            .alert("Received an invite from \(rpsSession.recvdInviteFrom?.displayName ?? "ERR")!", isPresented: $rpsSession.recvdInvite) {
                Button("Accept invite") {
                    if (rpsSession.invitationHandler != nil) {
                        rpsSession.invitationHandler!(true, rpsSession.session)
                    }
                }
                Button("Reject invite") {
                    if (rpsSession.invitationHandler != nil) {
                        rpsSession.invitationHandler!(false, nil)
                    }
                }
            }
        } else {
            GameView(rpsSession: rpsSession)
        }
    }
}
```

The buttons created inside of the List, when pressed, will call invitePeer on our serviceBrowser to send an invitation to the other player. This method is provided by the serviceBrowser and is not implemented by us.
The alert listens for changes to the recvdInvite bool in our session object. If the user selects the "Accept invite" button, we call the invitation handler with a true value and our current session. Otherwise, we pass the invitation handler false and don't bother with the session.
When either us or the other player receive and accept an invitation, the MCSessionDelegate's "peer didChange" method is called with state being .connected. If you go back and look at that method you'll see we set paired to true which changes the view on screen to the GameView and passes along our rpsSession.
That brings us along to the GameView.
Since this isn't so much a SwiftUI tutorial and more of a how-to on using Multipeer Connectivity with it, I won't dive too deep into the nitty gritty of my layout since it is pretty wordy.
Instead, I'll break down the logic parts and show how I accomplished receiving and sending moves.
The layout is comprised of a VStack containing the opponents move (either a thought bubble while the timer counts down or the opponents sent move when the timer expires), a Text that counts down from 10, our current move, and a HStack containing 3 buttons (rock, paper and scissors).
Here's the full implementation of GameView:

```swift
import SwiftUI

enum Result {
    case win, loss, tie
}

struct GameView: View {
    @StateObject var rpsSession: RPSMultipeerSession
    
    @State var timeLeft = 10
    @State var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State var currentMove: Move = .unknown
    @State var opponentMove: Move = .unknown
    @State var showResult: Bool = false
    @State var result: Result = .tie
    @State var resultMessage: String = ""
    
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                // Opponent - 🪨 📄 ✂️
                Image(opponentMove.description)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .padding(.top)
                    .padding()
                
                // Timer - 10
                Text("\(timeLeft)")
                    .font(.system(size: 30))
                    .onReceive(timer) { input in
                        if (timeLeft > 0) {
                            timeLeft -= 1
                        } else {
                            timeLeft = 10
                            timer.upstream.connect().cancel()
                            // Call timer.upstream.connect() to restart the timer
                            switch rpsSession.receivedMove {
                            case .rock:
                                opponentMove = .rock
                                break
                            case .paper:
                                opponentMove = .paper
                                break
                            case .scissors:
                                opponentMove = .scissors
                                break
                            default:
                                // TODO: Invalid, big red X or something idk
                                opponentMove = .unknown
                                break
                            }
                            //TODO: Show winning/losing screen and restart button
                            result = score(opponentMove: opponentMove, ourMove: currentMove)
                            if (result == .win) {
                                resultMessage = "You won!"
                            } else if (result == .loss) {
                                resultMessage = "You lost!"
                            } else {
                                resultMessage = "It's a tie!"
                            }
                            showResult = true
                        }
                    }
                // Player - Move
                Image(currentMove.description)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .padding()
                    .padding(.bottom, 20)
                // Moves - Moves
                HStack {
                    Button(action: {
                        currentMove = .rock
                        rpsSession.send(move: .rock)
                    }, label: {
                        Image("Rock")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40)
                    })
                        .buttonStyle(BorderlessButtonStyle())
                        .padding()
                    
                    Button(action: {
                        currentMove = .paper
                        rpsSession.send(move: .paper)
                    }, label: {
                        Image("Paper")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40)
                    })
                        .buttonStyle(BorderlessButtonStyle())
                        .padding()
                    
                    Button(action: {
                        currentMove = .scissors
                        rpsSession.send(move: .scissors)
                    }, label: {
                        Image("Scissors")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40)
                    })
                        .buttonStyle(BorderlessButtonStyle())
                        .padding()
                }
            }
            if (showResult) {
                VStack(alignment: .center, spacing: 10) {
                    Text(resultMessage)
                        .fontWeight(.heavy)
                    Text("Would you like to play again?")
                        .fontWeight(.regular)
                    Button("Yes") {
                        showResult = false
                        //TODO: Send restart message to peer, wait for response
                    }
                    Button("No") {
                        rpsSession.session.disconnect()
                    }
                }.zIndex(1)
                    .frame(width: 400, height: 500)
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
    }
    
    func score(opponentMove: Move, ourMove: Move) -> Result {
        switch opponentMove {
        case .rock:
            if ourMove == .scissors {
                return .loss
            } else if ourMove == .paper {
                return .win
            } else {
                return .tie
            }
        case .paper:
            if ourMove == .rock {
                return .loss
            } else if ourMove == .scissors {
                return .win
            } else {
                return .tie
            }
        case .scissors:
            if ourMove == .paper {
                return .loss
            } else if ourMove == .rock {
                return .win
            } else {
                return .tie
            }
        default:
            // Invalid move somewhere
            return .tie
        }
    }
}
```

You can see the timer updates every second and, when it reaches zero, checks if we received a move from our opponent to score and announce a winner. Every time a move button is pressed, we set currentMove, which then updates the image on our current move, and send the move to our opponent.
This implementation is fine. It does what I wanted and finally we can use MPC with SwiftUI 4 without the need for any UIKit garbage (sorry). But it isn't perfect. Aside from the obvious issues with error handling, ugly UI elements, lack of communication with the user regarding a rejected invitation, no implemented way to restart or leave a game, etc., the main issue with my implementation is the Timer. The timers will often go out of sync since the timer on the device that received the invitation will start a fraction of a second before the timer on the device that sent the invitation (it knows the invitation was accepted first, after all). I have a few ideas to fix this issue.
I believe the best solution would be to have the device that starts the game (the one that accepts the invitation) stream the timer to the other device after the other device has switched to the game view. Basically once the game view is shown, the second device would send a message to the first one notifying it to start streaming the timer.
That might be better but it also might have the same issue and it seems a little bit overkill. The delay in the timer is not a huge deal considering the players wouldn't be looking at each others' screens anyway or else what would be the point?
But for fun, I'm going to sit up and try and get my stream implementation working. It might be worth it to learn about how data is streamed over MPC for future projects. When I'm done tackling that I'll post a follow-up here and plan on making a full step-by-step youtube tutorial.
Thanks for reading and leave some comments if you have some suggestions or noticed something I missed!
