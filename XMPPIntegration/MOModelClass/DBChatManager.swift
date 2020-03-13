//
//  DBChatManager.swift
//  XMPPIntegration
//
//  Created by Ahmed Durrani on 11/01/2019.
//  Copyright © 2019 TeachEase Solution. All rights reserved.
//

import UIKit
import XMPPFramework

let SharedDBChatManager = DBChatManager.shareInstance()

class DBChatManager: NSObject , XMPPRosterDelegate , XMPPMUCDelegate , XMPPRoomLightStorage  {
    func handleIncomingMessage(_ message: XMPPMessage, room: XMPPRoomLight) {
        
    }
    
    func handleOutgoingMessage(_ message: XMPPMessage, room: XMPPRoomLight) {
        
    }
    

    private(set)    var  xmppStream                      : XMPPStream?
    private(set)    var  xmppReconnect                   : XMPPReconnect?
    private(set)    var  xmppRoster                      : XMPPRoster?
    private(set)    var  xmppRosterStorage               : XMPPRosterCoreDataStorage?
    private(set)    var  xmppvCardStorage                : XMPPvCardCoreDataStorage?
    private(set)    var  xmppvCardTempModule             : XMPPvCardTempModule?
    private(set)    var  xmppvCardAvatarModule           : XMPPvCardAvatarModule?
    private(set)    var  xmppCapabilities                : XMPPCapabilities?
    private(set)    var  xmppCapabilitiesStorage         : XMPPCapabilitiesCoreDataStorage?
    private(set)    var  xmppPing                        : XMPPPing?
    private(set)    var  xmppMUC                         : XMPPMUC?
    private(set)    var  xmppRoom                        : XMPPRoom?
    private(set)    var  xmppStreamManagement            : XMPPStreamManagement?
    private(set)    var  xmppStorage                     : XMPPMessageArchivingCoreDataStorage?
    private(set)    var  xmppMessageArchivingModule      : XMPPMessageArchiving?
    private(set)    var  socketsConnect                  : GCDAsyncSocket?
    private(set)    var  xmppLastSeenActivity            : XMPPLastActivity?
    private(set)    var  xmppAutoPing                    : XMPPAutoPing?
    private(set)    var  xmppMUCLight                    : XMPPMUCLight?
    private         let  mucLightServiceName             = "muclight.erlang-solutions.com"
    private         var         xmppMessageArchivingStorage: XMPPMessageArchivingCoreDataStorage?
    private         var xmppMessageArchiveManagement: XMPPMessageArchiveManagement?
    private         var xmppRoomLightCoreDataStorage: XMPPRoomLightCoreDataStorage?
    private         var xmppMessageDeliveryReceipts: XMPPMessageDeliveryReceipts?
//    private         var xmppRetransmission                  :  XMPPRetransmission?
//    private(set)    var xmppOutOfBandMessaging              :  XMPPOutOfBandMessaging?
    

    var roomsLight = [XMPPRoomLight]() {
        willSet {
            for removedRoom in (roomsLight.filter { !newValue.contains($0) }) {
                xmppMessageArchiveManagement?.removeDelegate(removedRoom)
//                xmppMessageArchiveManagement.removeDelegate(removedRoom)
                xmppMessageArchiveManagement?.removeDelegate(removedRoom)
//                xmppRetransmission?.removeDelegate(removedRoom)
//                xmppOutOfBandMessaging?.removeDelegate(removedRoom)
//                xmppRetransmission.removeDelegate(removedRoom)
//                xmppOutOfBandMessaging.removeDelegate(removedRoom)
                removedRoom.removeDelegate(self)
                removedRoom.removeDelegate(self.xmppRoomLightCoreDataStorage!)
                removedRoom.deactivate()
            }
        }
        didSet {
            for insertedRoom in (roomsLight.filter { !oldValue.contains($0) }) {
                insertedRoom.shouldStoreAffiliationChangeMessages = true
                insertedRoom.activate(xmppStream!)
                insertedRoom.addDelegate(self, delegateQueue: .main)
                insertedRoom.addDelegate(self.xmppRoomLightCoreDataStorage!, delegateQueue: insertedRoom.moduleQueue)
                xmppMessageArchiveManagement?.addDelegate(insertedRoom, delegateQueue: insertedRoom.moduleQueue)
                
//                xmppMessageArchiveManagement.addDelegate(insertedRoom, delegateQueue: insertedRoom.moduleQueue)
//                xmppRetransmission.addDelegate(insertedRoom, delegateQueue: insertedRoom.moduleQueue)
//                xmppOutOfBandMessaging.addDelegate(insertedRoom, delegateQueue: insertedRoom.moduleQueue)
                
                retrieveMessageHistory(fromArchiveAt: insertedRoom.roomJID, lastPageOnly: true)
            }
            
            roomListDelegate?.roomListDidChange(in: self)
        }
    }

    var customCertEvaluation = false
    var isXmppConnected = false
    var password : String?
    weak var roomListDelegate: XMPPControllerRoomListDelegate?


    // Single Method
    static let shareInstanceShared: DBChatManager? = {
        var shared = DBChatManager()
        return shared
    }()
    
    class func shareInstance() -> DBChatManager? {
        // `dispatch_once()` call was converted to a static variable initializer
        
        return shareInstanceShared
    }
    
    
    override init() {
        super.init()
    }
    
    // MARK:  Establish Connections
    
    func makeConnectionWithChatServer() {
        
        // Setup the XMPP stream
        
        self.setupStream()
        self.setupConnection()

        
    }
    
    func setupConnection() {
        if !connect() {
            print("Connection Failed")
        }
        
    }
    
    func setupStream() {
        
        if !(xmppStream != nil) {
            assert(xmppStream == nil, "Method setupStream invoked multiple times")
        }
        
        // Setup xmpp stream
        //
        // The XMPPStream is the base class for all activity.
        // Everything else plugs into the xmppStream, such as modules/extensions and delegates.

        
        xmppStream = XMPPStream()
        
        #if !TARGET_IPHONE_SIMULATOR
        // Want xmpp to run in the background?
        //
        // P.S. - The simulator doesn't support backgrounding yet.
        //        When you try to set the associated property on the simulator, it simply fails.
        //        And when you background an app on the simulator,
        //        it just queues network traffic til the app is foregrounded again.
        //        We are patiently waiting for a fix from Apple.
        //        If you do enableBackgroundingOnSocket on the simulator,
        //        you will simply see an error message from the xmpp stack when it fails to set the property.
        
        xmppStream!.enableBackgroundingOnSocket = true
        
        #endif

        // Setup reconnect
        //
        // The XMPPReconnect module monitors for "accidental disconnections" and
        // automatically reconnects the stream for you.
        // There's a bunch more information in the XMPPReconnect header file.
        
        xmppReconnect = XMPPReconnect()
        self.xmppMUCLight = XMPPMUCLight()

        xmppReconnect?.addDelegate(self, delegateQueue: DispatchQueue.main)
        
        // Setup roster
        //
        // The XMPPRoster handles the xmpp protocol stuff related to the roster.
        // The storage for the roster is abstracted.
        // So you can use any storage mechanism you want.
        // You can store it all in memory, or use core data and store it on disk, or use core data with an in-memory store,
        // or setup your own using raw SQLite, or create your own storage mechanism.
        // You can do it however you like! It's your application.
        // But you do need to provide the roster with some storage facility.
        //    xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:xmppRosterStorage];
        
          xmppRosterStorage = XMPPRosterCoreDataStorage.sharedInstance()
          xmppRoster = XMPPRoster(rosterStorage: xmppRosterStorage!)
        
          xmppRoster?.autoFetchRoster = true
          xmppRoster?.autoAcceptKnownPresenceSubscriptionRequests = true
        
        // Setup vCard support
        //
        // The vCard Avatar module works in conjuction with the standard vCard Temp module to download user avatars.
        // The XMPPRoster will automatically integrate with XMPPvCardAvatarModule to cache roster photos in the roster.
        
        xmppvCardStorage = XMPPvCardCoreDataStorage.sharedInstance()
        xmppvCardTempModule = XMPPvCardTempModule(vCardStorage: xmppvCardStorage!)
        xmppvCardAvatarModule = XMPPvCardAvatarModule(vCardTempModule: xmppvCardTempModule!)
        
        xmppPing = XMPPPing()
        xmppAutoPing = XMPPAutoPing()
        xmppMUC = XMPPMUC(dispatchQueue: DispatchQueue.main)
        xmppLastSeenActivity = XMPPLastActivity(dispatchQueue: DispatchQueue.main)
        
        
        
        // Setup capabilities
        //
        // The XMPPCapabilities module handles all the complex hashing of the caps protocol (XEP-0115).
        // Basically, when other clients broadcast their presence on the network
        // they include information about what capabilities their client supports (audio, video, file transfer, etc).
        // But as you can imagine, this list starts to get pretty big.
        // This is where the hashing stuff comes into play.
        // Most people running the same version of the same client are going to have the same list of capabilities.
        // So the protocol defines a standardized way to hash the list of capabilities.
        // Clients then broadcast the tiny hash instead of the big list.
        // The XMPPCapabilities protocol automatically handles figuring out what these hashes mean,
        // and also persistently storing the hashes so lookups aren't needed in the future.
        //
        // Similarly to the roster, the storage of the module is abstracted.
        // You are strongly encouraged to persist caps information across sessions.
        //
        
          xmppReconnect?.activate(xmppStream!)
          xmppRoster?.activate(xmppStream!)
          xmppvCardTempModule?.activate(xmppStream!)
          xmppvCardAvatarModule?.activate(xmppStream!)
          xmppCapabilities?.activate(xmppStream!)
          xmppPing?.activate(xmppStream!)
          xmppRoom?.activate(xmppStream!)
          xmppAutoPing?.activate(xmppStream!)
          xmppStreamManagement?.activate(xmppStream!)
          xmppMUC?.activate(xmppStream!)
          xmppLastSeenActivity?.activate(xmppStream!)
          xmppMUCLight?.activate(xmppStream!)
          

        // Add ourself as a delegate to anything we may be interested in
        
          xmppStream?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppReconnect?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppRoster?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppvCardTempModule?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppPing?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppRoom?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppMUC?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppAutoPing?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppStreamManagement?.addDelegate(self, delegateQueue: DispatchQueue.main)
          xmppLastSeenActivity?.addDelegate(self, delegateQueue: DispatchQueue.main)
            xmppMUCLight?.addDelegate(self.xmppMUCLight!, delegateQueue: self.xmppMUCLight!.moduleQueue)
        
        // Optional:
        //
        // Replace me with the proper domain and port.
        // The example below is setup for a typical google talk account.
        //
        // If you don't supply a hostName, then it will be automatically resolved using the JID (below).
        // For example, if you supply a JID like 'user@quack.com/rsrc'
        // then the xmpp framework will follow the xmpp specification, and do a SRV lookup for quack.com.
        //
        // If you don't specify a hostPort, then the default (5222) will be used.
        // host Name replace with your hostName and also set your own port i have pass dummy hostName
        
        xmppStream?.hostName = "132.148.144.24"
        xmppStream?.hostPort = 5222
        

        
        
        
    }
    
    deinit {
        self.teardownStream()
    }

    func teardownStream() {
        xmppStream?.removeDelegate(self)
        xmppRoster?.removeDelegate(self)
        xmppReconnect?.deactivate()
        xmppvCardTempModule?.deactivate()
        xmppvCardAvatarModule?.deactivate()
        xmppCapabilities?.deactivate()
        xmppPing?.deactivate()
        xmppMUC?.deactivate()
        xmppStream?.disconnect()
        xmppStream                 = nil;
        xmppReconnect              = nil;
        xmppRoster                 = nil;
        xmppRosterStorage          = nil;
        xmppvCardStorage           = nil;
        xmppvCardTempModule        = nil;
        xmppvCardAvatarModule      = nil;
        xmppCapabilities           = nil;
        xmppCapabilitiesStorage    = nil;
        xmppPing                   = nil;
        xmppMUC                    = nil;
        xmppMUCLight  = nil
        self.roomsLight.forEach { (roomLight) in
            self.xmppMessageArchiveManagement?.removeDelegate(roomLight)
//            self.xmppOutOfBandMessaging.removeDelegate(roomLight)
            roomLight.removeDelegate(self)
            roomLight.deactivate()
        }
        
        NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextObjectsDidChange, object: self.managedObjectContext_roster())

        
        
    }
    
//    - (void)teardownStream {
//
//    [xmppStream removeDelegate:self];
//    [xmppRoster removeDelegate:self];
//
//    [xmppReconnect          deactivate];
//    [xmppRoster             deactivate];
//    [xmppvCardTempModule    deactivate];
//    [xmppvCardAvatarModule  deactivate];
//    [xmppCapabilities       deactivate];
//    [xmppPing               deactivate];
//    [xmppMUC           deactivate];
//
//    [xmppStream disconnect];
//
//    xmppStream                 = nil;
//    xmppReconnect              = nil;
//    xmppRoster                 = nil;
//    xmppRosterStorage          = nil;
//    xmppvCardStorage           = nil;
//    xmppvCardTempModule        = nil;
//    xmppvCardAvatarModule      = nil;
//    xmppCapabilities           = nil;
//    xmppCapabilitiesStorage    = nil;
//    xmppPing                   = nil;
//    xmppMUC                    = nil;
//    AppUtility.isOnlineForChat = NO  ;
//
//    }


    // MARK Disconnect Connection from XMPP
    
    func disconnectXMPP() {
        xmppStream?.removeDelegate(self)
        xmppReconnect?.deactivate()
        xmppStream?.disconnect()
        
    }
    
    func connect() -> Bool {
        if !(xmppStream?.isDisconnected)! {
            return true
        }
        
        // JID depend on your requirement like in my situation the hostname is opchat.com and on which basis you want to make the JID you cant make the userID or many other unique record like phone number or any other
//        let userId = "21"
        let jabberID = "21@ibexglobal.com"
        
        if jabberID == nil {
            return  false
        }
        
        password = jabberID
        let jid = XMPPJID(string: jabberID, resource: nil)
        xmppStream?.myJID = jid
        
        if !(((try? xmppStream?.connect(withTimeout: XMPPStreamTimeoutNone)) != nil)) {
            return false
        }
        return true
    }
    
//    XMPPPresence *presence = [XMPPPresence presenceWithType:@"available"];// type="available" is implicit
//    NSXMLElement *element =  [NSXMLElement elementWithName:@"priority" numberValue:@(24)];
//    [presence addChild:element];
//    NSXMLElement *nextText = [NSXMLElement elementWithName:@"text" numberValue:@(4)];
//    [presence addChild:nextText];
//    [[self xmppStream] sendElement:presence];
//    AppUtility.isOnlineForChat  = YES;
    func goOnline() {
        let presence = XMPPPresence(name: "available")
        let element =  XMLElement(name: "priority", numberValue: 24)
        presence.addChild(element)
        let nextText = XMLElement(name:"text" , numberValue: 4)
        presence.addChild(nextText)
        xmppStream?.send(presence)
    }
    
    func goOffline() {
        let presence = XMPPPresence(name: "unavailable")
        xmppStream?.send(presence)

    }
    
    func getPresenceForJid(jidStr : String) {
        let presence = XMPPPresence(name: "available")
        xmppStream?.send(presence)
        
    }

    // MARK: XMPPRoom Delegate
    
    func ConfigureNewRoom() {
        
        xmppRoom?.fetchConfigurationForm()
        xmppRoom?.configureRoom(usingOptions: nil)
        
    }
    
    func retrieveMessageHistory(fromArchiveAt archiveJid: XMPPJID? = nil, startingAt startDate: Date? = nil, filteredBy filteringJid: XMPPJID? = nil, lastPageOnly: Bool = false) {
        let queryFields = [
            startDate.map { XMPPMessageArchiveManagement.field(withVar: "start", type: nil, andValue: ($0 as NSDate).xmppDateTimeString)},
            filteringJid.map { _ in XMPPMessageArchiveManagement.field(withVar: "with", type: nil, andValue: archiveJid?.bare ?? "") }
            ].compactMap { $0 }
        
        let resultSet = lastPageOnly ? XMPPResultSet(max: NSNotFound, before: "") : XMPPResultSet(max: NSNotFound, after: "")
        
//        xmppMessageArchiveManagement.retrieveMessageArchive(at: archiveJid?.full  , withFields: queryFields, with: resultSet)
    }

    func addRoom(withName roomName: String, initialOccupantJids: [XMPPJID]?) {
        let addedRoom = XMPPRoomLight(jid: XMPPJID(string: mucLightServiceName)!, roomname: roomName)
        addedRoom.addDelegate(self, delegateQueue: DispatchQueue.main)
        addedRoom.activate(xmppStream!)
        
        roomsLight.append(addedRoom)
        
        addedRoom.createRoomLight(withMembersJID: initialOccupantJids)
    }


}

//extension DBChatManager : XMPPMUCLightDelegate {
//
//    func xmppMUCLight(_ sender: XMPPMUCLight, didDiscoverRooms rooms: [DDXMLElement], forServiceNamed serviceName: String) {
//        roomsLight = rooms.map { (rawElement) -> XMPPRoomLight in
//            let rawJid = rawElement.attributeStringValue(forName: "jid")
//            let rawName = rawElement.attributeStringValue(forName: "name")!
//            let jid = XMPPJID(string: rawJid!)!
//
//            if let existingRoom = (roomsLight.first { $0.roomJID == jid}) {
//                return existingRoom
//            } else {
//
//                let filteredRoomLightStorage = XMPPRetransmissionRoomLightStorageFilter(baseStorage: xmppRoomLightCoreDataStorage, xmppRetransmission: xmppRetransmission)
//                return XMPPRoomLight(roomLightStorage: filteredRoomLightStorage, jid: jid, roomname: rawName, dispatchQueue: .main)
//            }
//        }
//    }
//
//    func xmppMUCLight(_ sender: XMPPMUCLight, changedAffiliation affiliation: String, roomJID: XMPPJID) {
//        self.xmppMUCLight!.discoverRooms(forServiceNamed: mucLightServiceName)
//    }
//
//}

extension DBChatManager : XMPPStreamDelegate {
    func xmppStream(_ sender: XMPPStream, socketDidConnect socket: GCDAsyncSocket) {
        
    }
    
    func xmppStream(_ sender: XMPPStream, didFailToSend message: XMPPMessage, error: Error) {
        
    }
    
    func xmppStream(_ sender: XMPPStream, didSend message: XMPPMessage) {
        // This method called whent the message send successfully
        
        
    }
    
    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        if !isXmppConnected {
            print("Unable to connect to server. Check xmppStream.hostName")

        }
    }
    
    func xmppStreamDidRegister(_ sender: XMPPStream) {
        
        let topVC = UIApplication.shared.keyWindow?.rootViewController
        let alert = UIAlertController(title: "Registration", message: "Registration with XMPP Successful!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        
        
        topVC!.present(alert, animated: true)

        
    }
    
    func xmppStream(_ sender: XMPPStream, didNotRegister error: DDXMLElement) {
        
        let errorXML  = error.element(forName: "error")
        let errorCode = errorXML?.attribute(forName: "code")?.stringValue
        let topVC = UIApplication.shared.keyWindow?.rootViewController

        let alert = UIAlertController(title: "Registration", message: "Registration with XMPP   Failed!", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        

        if errorCode == "409" {
            alert.message = "Username Already Exists!"
        }
        topVC!.present(alert, animated: true)

    }
    
    func xmppStream(_ sender: XMPPStream, willSecureWithSettings settings: NSMutableDictionary) {
        let expectedCertName = xmppStream?.myJID?.domain
        
        if expectedCertName != "" {
            settings[kCFStreamSSLPeerName as? String ?? ""] = expectedCertName
        }
        
        if customCertEvaluation {
            settings[GCDAsyncSocketManuallyEvaluateTrust] = true
        }
        
    }
    
    func xmppStream(_ sender: XMPPStream, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        let bgQueue = DispatchQueue.global(qos: .default)
        bgQueue.async(execute: {
            
            var result: SecTrustResultType = .deny
            let status: OSStatus = SecTrustEvaluate(trust, &result)
            
            if status == noErr && (result == .proceed || result == .unspecified) {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        })
    }
    
    func xmppStreamDidSecure(_ sender: XMPPStream) {
        
    }
    
    func xmppStreamDidConnect(_ sender: XMPPStream) {
        
        isXmppConnected = true
        let authenticateError : NSError? = nil
        if !(((try? xmppStream!.authenticate(withPassword: password!)) != nil)) {
//            print("Authentication error: \(authenticateError!.localizedDescription)")
            //        DDLogError(@"Error authenticating: %@", error);
        }

        
    }
    
    func xmppStreamDidAuthenticate(_ sender: XMPPStream) {
        goOnline()
    }
    
    func xmppStream(_ sender: XMPPStream, didNotAuthenticate error: DDXMLElement) {
        
         try?  xmppStream?.register(withPassword: password!)
        let err : NSError? = nil
        
        if !(((try? xmppStream!.register(withPassword: password!)) != nil)) {
            print("Error registering: \(err!)")
        }
        
        
        if !(((try? xmppStream!.register(withPassword: password!)) != nil)) {
            print("Error registering: \(err!)")
        }
        
        DispatchQueue.main.async(execute: {
            
            self.teardownStream()
            self.setupConnection()
        })
    }
    
    func xmppStream(_ sender: XMPPStream, didReceive iq: XMPPIQ) -> Bool {
        return false;

    }
    
    func xmppStream(_ sender: XMPPStream, didReceive presence: XMPPPresence) {
//        NSString *presenceType = [presence type];
//        NSString *myUsername = [[sender myJID] user];
//        NSString *presenceFromUser = [[presence from] user];
        
        let presenceType = presence.type
        let myUsername = sender.myJID?.user
        let presenceFromUser = presence.from?.user
        
        if myUsername == presenceFromUser {
            if presenceType == "available" {
//                NotifCentre.post(name: kPresenceUserOnline, object: presence)
            } else if  presenceType == "unavailable" {
//                xmppRoster?.acceptPresenceSubscriptionRequest(from: presence.from!, andAddToRoster: true)
                
//                [xmppRoster acceptPresenceSubscriptionRequestFrom:[presence from] andAddToRoster:YES];

            } else if  presenceType == "subscribe" {
                xmppRoster?.acceptPresenceSubscriptionRequest(from: presence.from!, andAddToRoster: true)
            } else if  presenceType == "unsubscribe" {
                xmppRoster?.removeUser(presence.from!)
                
            }
        
    }
}
    func xmppStream(_ sender: XMPPStream, didReceiveError error: DDXMLElement) {
        
    }
    
    // This method for Receive the message
    
    
    func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        
    }
    
    
}

protocol XMPPControllerRoomListDelegate: class {
    
    func roomListDidChange(in controller: DBChatManager)
}

extension DBChatManager : XMPPRoomLightDelegate {
    
    func xmppRoomLight(_ sender: XMPPRoomLight, didCreateRoomLight iq: XMPPIQ) {
//        xmppMUCLight.discoverRooms(forServiceNamed: mucLightServiceName)
        xmppMUCLight?.discoverRooms(forServiceNamed: mucLightServiceName)
    }
    
    func xmppRoomLight(_ sender: XMPPRoomLight, configurationChanged message: XMPPMessage) {
        roomListDelegate?.roomListDidChange(in: self)
    }
}

extension DBChatManager {
    func managedObjectContext_roster() -> NSManagedObjectContext {
//        return self.xmppRosterStorage?.mainThreadManagedObjectContext
        return (self.xmppRosterStorage?.mainThreadManagedObjectContext)!
    }
}

