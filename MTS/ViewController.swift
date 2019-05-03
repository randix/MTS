//
//  ViewController.swift
//  MTS
//
//  Created by Rand Dow on 4/29/19.
//  Copyright © 2019 Rand Dow. All rights reserved.
//

import UIKit
import Network

class ViewController: UIViewController {

    var client: MTSClient?
    
//    required init?(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)
//        //fatalError("init(coder:) has not been implemented")
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = .white
        
        // I'm a RMSServer
        var button = UIButton(frame: CGRect(x: 30, y: 100, width: 200, height: 50))
        button.backgroundColor = .blue
        button.setTitle("Connect FrontDesk", for: .normal)
        button.addTarget(self, action: #selector(buttonConnectFD), for: .touchUpInside)
        self.view.addSubview(button)
        
        button = UIButton(frame: CGRect(x: 240, y: 100, width: 100, height: 50))
        button.backgroundColor = .green
        button.setTitle("Login", for: .normal)
        button.addTarget(self, action: #selector(buttonLogin), for: .touchUpInside)
        self.view.addSubview(button)
        
        // I'm a RMSRoomNode
        button = UIButton(frame: CGRect(x: 30, y: 200, width: 200, height: 50))
        button.backgroundColor = .red
        button.setTitle("Connect RMSServer", for: .normal)
        button.addTarget(self, action: #selector(buttonConnectRMS), for: .touchUpInside)
        self.view.addSubview(button)
        
        button = UIButton(frame: CGRect(x: 240, y: 200, width: 100, height: 50))
        button.backgroundColor = .gray
        button.setTitle("Enroll", for: .normal)
        button.addTarget(self, action: #selector(buttonEnrollRMS), for: .touchUpInside)
        self.view.addSubview(button)
        
        // I'm a Lock
        button = UIButton(frame: CGRect(x: 20, y: 300, width: 210, height: 50))
        button.backgroundColor = .red
        button.setTitle("Connect RMSRoomNode", for: .normal)
        button.addTarget(self, action: #selector(buttonConnectRMSRmNd), for: .touchUpInside)
        self.view.addSubview(button)
        
        button = UIButton(frame: CGRect(x: 240, y: 300, width: 100, height: 50))
        button.backgroundColor = .gray
        button.setTitle("Enroll", for: .normal)
        button.addTarget(self, action: #selector(buttonEnrollRMSRmNd), for: .touchUpInside)
        self.view.addSubview(button)
        
        
        print("Hello")

    }
    
    @objc func buttonConnectFD(sender: UIButton!) {
        print("connect FD")
        client = MTSClient(useTLS: false, clientCert: nil, host: "172.20.10.5", port: 10001,
                           mtsReceiver: mtsReceiver, proxy: nil, proxyUser: nil, proxyPassword: nil)
    }
    
    @objc func buttonLogin(sender: UIButton!)
    {
        let login = Login(user:"user", password:"password")
        let jsonEncoder = JSONEncoder()
        var json : String = ""
        do {
            let jsonData = try jsonEncoder.encode(login)
            json = String(data: jsonData, encoding: String.Encoding.utf8)!
        } catch {
            print("json convert error")
        }
        let mtsMessage = MTSMessage(route:"Login", json:json)
        do {
            let jsonData = try jsonEncoder.encode(mtsMessage)
            json = String(data: jsonData, encoding: String.Encoding.utf8)!
        } catch {
            print("json convert error")
        }
        print(json)
        client!.send(json.data(using: String.Encoding.utf8)!)
    }
    
    @objc func buttonConnectRMS(sender: UIButton!)
    {
        print("connect RMS (with MTS)")
    }
    
    @objc func buttonEnrollRMS(sender: UIButton!)
    {
        print("enroll RMS (with MTS)")
    }
    
    @objc func buttonConnectRMSRmNd(sender: UIButton!)
    {
        print("connect RMSRmNd (with OPL)")
    }
    @objc func buttonEnrollRMSRmNd(sender: UIButton!)
    {
        print("enroll RMSRmNd (with OPL)")
    }
    
    func mtsReceiver(_ json: String) {
        
        print("data \(json)")
    }


}

