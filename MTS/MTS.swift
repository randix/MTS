//
//  MTS.swift
//  MTS
//
//  Created by Rand Dow on 5/1/19.
//  Copyright © 2019 Rand Dow. All rights reserved.

import Foundation
import Network

// helper functions
func MTSconvert(_ from: MTSMessage) throws -> Data {
    return try! JSONEncoder().encode(from)
}

func MTSconvert(_ from: Data) throws -> MTSMessage {
    return try! JSONDecoder().decode(MTSMessage.self, from: from)
}

// primary message structure
struct MTSMessage: Codable {
    var route: Int
    var jwt: String
    var data: Data
    var reply: Bool
    
    init(route: MTSRequest, jwt: String, data: Data, reply: Bool = false) {
        self.route = route.rawValue
        self.jwt = jwt
        self.data = data
        self.reply = reply
    }
}

class MTSServer {
    
    private let log: (_ log: String) -> Void
    private let port: UInt16
    private let mtsConnect: (_ client: MTSClient) -> Void
    private let mtsReceive: (_ from: MTSClient, _ message: MTSMessage) -> Void
    private let mtsDisconnect: (_ client: MTSClient) -> Void
    
    private var useTLS = false
    private var certificate: Data?
    private var clientCertRequired = false
    
    private var listener: NWListener?
    private var clients: [MTSClient]
    
    init(log: @escaping (_ log: String) -> Void, port: UInt16,
         mtsConnect: @escaping (_ client: MTSClient) -> Void,
         mtsReceive: @escaping (_ from: MTSClient, _ receive: MTSMessage) -> Void,
         mtsDisconnect: @escaping (_ from: MTSClient) -> Void) {
        self.log = log
        self.port = port
        self.mtsConnect = mtsConnect
        self.mtsReceive = mtsReceive
        self.mtsDisconnect = mtsDisconnect
        clients = []
    }
    
    @discardableResult
    func withTLS(certificate: Data, clientCertificateRequired: Bool) -> MTSServer {
        useTLS = true
        self.certificate = certificate
        clientCertRequired = clientCertificateRequired
        return self
    }
    
    func clientCertificateRequired(_ clientCertificateRequired: Bool) {
        clientCertRequired = clientCertificateRequired
    }
    
    @discardableResult
    func start() -> MTSServer {
        var p: NWParameters
        if useTLS {
            p = createTLSParameters(allowInsecure: true, queue: .main)
        } else {
            p = NWParameters.tcp
        }
        p.allowLocalEndpointReuse = true
        
        listener = try! NWListener(using: p, on: NWEndpoint.Port(rawValue: port)!)
        listener!.stateUpdateHandler = { (newState) in
            switch newState {
            case .cancelled:
                self.log("cancelled")
                break
            case .failed(let error):
                self.log("failed \(error)")
                break
            case .ready:
                self.log("ready")
                break
            case .setup:
                self.log("setup")
                break
            case .waiting(let error):
                self.log("waiting \(error)")
                break
            default:
                self.log("unknown \(newState)")
                break
            }
        }
        listener!.newConnectionHandler = { (newConnection) in
            // Handle inbound connections
            let client = MTSClient(log: self.log, url: newConnection.endpoint.debugDescription, mtsConnect: self.mtsConnect, mtsReceive: self.mtsReceive, mtsDisconnect: self.mtsDisconnectServer, connection: newConnection)
            // mtsConnect(mtsClient)
            newConnection.start(queue: .main)
        }
        return self
    }
    
    func stop() -> Void {
        
    }
    
    func mtsDisconnectServer(_ client: MTSClient) {
        // clean up, then
        mtsDisconnect(client)
        
    }
    
    func send(_ message: MTSMessage, to: MTSClient) -> Void {
        
    }
    
    func createTLSParameters(allowInsecure: Bool, queue: DispatchQueue) -> NWParameters {
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            var error: CFError?
            if SecTrustEvaluateWithError(trust, &error) {
                sec_protocol_verify_complete(true)
            } else {
                // TODO: determine if client cert is required and present
                // self.clientCertRequired
                
                if allowInsecure == true {
                    sec_protocol_verify_complete(true)
                } else {
                    sec_protocol_verify_complete(false)
                }
            }
        }, queue)
        return NWParameters(tls: options)
    }
}

class MTSClient {
    
    private let log: (_ log: String) -> Void
    private let url: URL
    private let mtsConnect: (_ client: MTSClient) -> Void
    private let mtsReceive: (_ client: MTSClient, _ receive: MTSMessage) -> Void
    private let mtsDisconnect: (_ client: MTSClient) -> Void
    private let isServer = false
    
    private var connection: NWConnection?
    var connected = false
    
    private var useTLS = false
    private var clientCertificate: Data?
    
    private var proxyHostname: String?
    private var proxyPort: UInt16?
    private var proxyUser: String?
    private var proxyPassword: String?
    private var proxyTransactComplete = false
    
    private let await = DispatchSemaphore(value: 0)
    private var waiting = false
    
    private var buffer = Data()
    private var expected = 0
    
    init(log: @escaping (_ log: String) -> Void, url: String,
         mtsConnect: @escaping (_ client: MTSClient) -> Void,
         mtsReceive: @escaping (_ client: MTSClient, _ receive: MTSMessage) -> Void,
         mtsDisconnect: @escaping (_ client: MTSClient) -> Void,
         connection: NWConnection? = nil) {
        self.log = log
        self.url = URL(string: url)!
        self.mtsConnect = mtsConnect
        self.mtsReceive = mtsReceive
        self.mtsDisconnect = mtsDisconnect
        self.connection = connection
    }
    
    @discardableResult
    func withTLS(_ certificate: Data?) -> MTSClient {
        useTLS = true
        clientCertificate = certificate
        return self
    }
    
    @discardableResult
    func withProxy(_ ProxyURL: String, ProxyUser: String?, ProxyPassword: String?) -> MTSClient {
        let s = ProxyURL.components(separatedBy: ":")
        proxyHostname = s[0]
        proxyPort = UInt16(s[1])!
        proxyUser = ProxyUser
        proxyPassword = ProxyPassword
        return self
    }
    
    @discardableResult
    func connect() -> MTSClient {
        log("connect to \(url.host!):\(url.port!) (TLS=\(useTLS))")
        // TODO client cert not implemented
        if connection != nil {
            // this was called from the server upon connection
            
        } else {
            // TODO proxy not implemented
            let myHost = NWEndpoint.Host(url.host!)
            let myPort =  NWEndpoint.Port(rawValue: UInt16(url.port!))!
            if useTLS {
                connection = NWConnection(host: myHost, port: myPort, using: createTLSParameters(allowInsecure: true, queue: .main))
            } else {
                connection = NWConnection(host: myHost, port: myPort, using: .tcp)
            }
        }
        connection!.stateUpdateHandler = stateDidChange
        setupReceive(on: connection)
        connection!.start(queue: .main)
        return self
    }
    
    func stateDidChange(to newState: NWConnection.State) {
        switch (newState) {
        case .ready:
            // Handle connection established
            log("connected")
            self.connected = true
            mtsConnect(self)
            break
        case .waiting(let error):
            // Handle connection waiting for network
            log("waiting \(error)")
            break
        case .failed(let error):
            // Handle fatal connection error
            log("failed \(error)")
            break
        case .preparing:
            // Handle fatal connection error
            log("preparing")
            break
        default:
            log("default \(newState)")
            break
        }
    }
    
    
    
    func setupReceive(on connection: NWConnection?) {
        connection!.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, contentContext, isComplete, error) in
            if var data = data, !data.isEmpty {
                // … process the data …
                print("receive")
                self.log("did receive \(data.count) \(self.expected) bytes")
                if (self.buffer.count == 0 && self.expected == 0) {
                    self.expected  = Int(data.removeFirst())
                    self.expected |= Int(data.removeFirst()) << 8
                    self.expected |= Int(data.removeFirst()) << 16
                    self.expected |= Int(data.removeFirst()) << 24
                    self.log("expected: \(self.expected) bytes")
                }
                self.buffer.append(data)
                self.log("have \(self.buffer.count) expected \(self.expected)")
                if (self.buffer.count == self.expected) {
                    let jsonDecoder = JSONDecoder()
                    let mtsMessage = try! jsonDecoder.decode(MTSMessage.self, from: self.buffer)
                    
                    if (self.waiting && mtsMessage.reply) {
                        self.waitReceiver(mtsMessage)
                    } else {
                        self.mtsReceive(self, mtsMessage)
                    }
                    self.buffer = Data()
                    self.expected = 0
                }
            }
            if isComplete {
                // … handle end of stream …
                self.Stop("EOF")
            } else if let error = error {
                // … handle error …
                print("error")
                self.connectionFailed(error: error)
            } else {
                print("restart receiver")
                self.setupReceive(on: connection)
            }
        }
    }
    
    func Stop(_ status: String) {
        print("stopping \(status)")
        sendEndOfStream()
    }
    
    func connectionFailed(error: NWError?) {
        print("error \(String(describing: error))")
    }
    
    func send(_ data: Data) {
        print("send")
        let len = data.count;
        var p: Data = Data()
        p.append(UInt8( len        & 0xff))
        p.append(UInt8((len >> 8)  & 0xff))
        p.append(UInt8((len >> 16) & 0xff))
        p.append(UInt8( len >> 24))
        connection!.send(content: p+data, completion: .contentProcessed(({ (error) in
            if let error = error {
                print("error \(String(describing: error))")
                self.connectionFailed(error: error)
            }
            print("processed")
        })))
        print("send finished")
    }
    
    func send(_ msg: MTSMessage) {
        let data = try! MTSconvert(msg)
        send(data)
    }
    
    var obj: AnyObject?
    func sendWait(_ data: MTSMessage) -> AnyObject {
        waiting = true
        send(data);
        await.wait()
        return obj!
    }
    func waitReceiver(_ mtsMessage: MTSMessage) {
        log("mtsMessage \(mtsMessage)")
        print(mtsMessage.route)
        let decoder = JSONDecoder()
        
        switch MTSRequest(rawValue: mtsMessage.route)! {
            
        case .LoginResponse:
            obj = try! decoder.decode(MtsLoginResponse.self, from: mtsMessage.data) as AnyObject
            break
            
        case .PPCommunicationKeys:
            obj = try! decoder.decode(PPCommunicationKeys.self, from: mtsMessage.data) as AnyObject
            break;
            
        case .RoomsMap:
            obj = try! decoder.decode(RoomToNodeIds.self, from: mtsMessage.data) as AnyObject
            break;
            
        case .OplCommands:
            obj = try! decoder.decode(OPLCommands.self, from: mtsMessage.data) as AnyObject
            break
            
        default:
            break
        }
        waiting = false
        await.signal()
    }
    
    // unused?
    func sendEndOfStream() {
        connection!.send(content: nil, contentContext: .defaultStream, isComplete: true, completion: .contentProcessed({ error in
            if let error = error {
                self.connectionFailed(error: error)
            }
        }))
    }
    
    func createTLSParameters(allowInsecure: Bool, queue: DispatchQueue) -> NWParameters {
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            var error: CFError?
            if SecTrustEvaluateWithError(trust, &error) {
                sec_protocol_verify_complete(true)
            } else {
                if allowInsecure == true {
                    sec_protocol_verify_complete(true)
                } else {
                    sec_protocol_verify_complete(false)
                }
            }
        }, queue)
        return NWParameters(tls: options)
    }
}
