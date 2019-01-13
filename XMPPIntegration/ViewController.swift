//
//  ViewController.swift
//  XMPPIntegration
//
//  Created by Ahmed Durrani on 11/01/2019.
//  Copyright © 2019 TeachEase Solution. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Login time First Make the connection with XMPP
        
        
        SharedDBChatManager?.makeConnectionWithChatServer()
        
        

    }


}

