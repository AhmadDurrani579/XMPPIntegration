# XMPPIntegration
An XMPP Framework in swift  and iOS

Abstract

XMPPFramework provides a core implementation of RFC-3920 (the XMPP standard), along with the tools needed to read & write XML. It comes with multiple popular extensions (XEP's), all built atop a modular architecture, allowing you to plug-in any code needed for the job. Additionally the framework is massively parallel and thread-safe. Structured using GCD, this framework performs well regardless of whether it's being run on an old iPhone, or on a 12-core Mac Pro. (And it won't block the main thread... at all)

Install

The minimum deployment target is iOS 10.0 

Swift

Its pure for swift 

CocoaPods

The easiest way to install XMPPFramework is using CocoaPods.

To install only the Objective-C portion of the framework:

pod 'XMPPFramework'
To use the new Swift additions:

use_frameworks!
pod 'XMPPFramework/Swift'
After pod install open the .xcworkspace and import:

@import XMPPFramework;   // Objective-C
import XMPPFramework     // Swift


Contributing

Pull requests are welcome! If you are planning a larger feature, please open an issue first for community input. Please use modern Swift syntax, including nullability annotations and generics. Here's some tips to make the process go more smoothly:

First Change the hostname with your host name and hostport number 
and next thing is chnage your domain name with my domain name and i have define every thing in DBChatManager class every thing of the xmpp requirement in DBChatManager class 








