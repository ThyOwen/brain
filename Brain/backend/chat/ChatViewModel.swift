//
//  ViewModel.swift
//  Brain
//
//  Created by Owen O'Malley on 5/4/24.
//

import Foundation
import Network

public typealias MessageReceivedCallback = (ServerMessage) -> Void
//public typealias ChatMessage = (user: String, text: String)

@Observable public final class ChatViewModel {
    
    // Network.framework needs a dedicated queue to operate on
    private let serverQueue = DispatchQueue(label: "chat-server-queue", qos: .background)

    private var connection: NWConnection? = nil
    let serverEndpoint: NWEndpoint

    public private(set) var loggedIn = false
    public let username: String
    public private(set) var chats : [Chat] = [Chat(messages: Chat.viewMessages)]
    public private(set) var activeChatID : UUID? = nil

    // Configurable notification callback that fires when we receive a message from the server
    var newMessageNotification: MessageReceivedCallback? = nil
    
    private var messageBoard : MessageBoard
    
    init(username: String, serverAddress: String, serverPort: Int, messageBoard : MessageBoard) {
        self.username = username
        self.messageBoard = messageBoard
        self.serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(serverAddress), port: NWEndpoint.Port(rawValue: UInt16(serverPort))!)

    }
    
    //MARK: - Networking

    func connect() {
        
        let options = NWProtocolTLS.Options()
        
        sec_protocol_options_set_tls_resumption_enabled(options.securityProtocolOptions, true)
        
        let params = self.getTLSParameters(allowInsecure: true)
        
        self.connection = NWConnection(to: serverEndpoint, using: params)

        // we should obtain a non-nil connection object
        guard let connection = self.connection else {
            self.messageBoard.postMessage("Invalid network connection")
            return
        }

        // 2. Setup our connection state handler that will manage transitions in the connection state
        self.setupConnectionStateHandler(connection)

        connection.start(queue: self.serverQueue)
        
        
        // 4. Start reading messages from the server. We need to read a first message then
        // our readNextMessage function will chain the next reads
        
        self.readNextMessage(connection)
    }

    deinit {
        self.disconnect()
    }
    
    func disconnect() {
        self.connection?.cancel()
    }

    private func setupConnectionStateHandler(_ connection: borrowing NWConnection) {
        
        connection.stateUpdateHandler = { (newState) in
            switch (newState) {
            case .setup:
                self.messageBoard.postTemporaryMessage("Connection setup")
                
            case .preparing:
                self.messageBoard.postTemporaryMessage("Connection preparing")
                
            case .ready:
                self.messageBoard.postTemporaryMessage("Connection established")
                // 1. once the connection is established, we need to tell the server who we are
                // TODO: self.send(command: .connect(username: self.username))
                self.send(.connect(username: self.username))
                
            case .waiting(let error):
                self.messageBoard.postTemporaryMessage("Connection to server waiting to establish ? \(error)")
                self.serverQueue.asyncAfter(deadline: .now() + 60) {
                    self.connect()
                }
                
            case .failed(let error):
                self.messageBoard.postTemporaryMessage("Connection to server failed ? \(error)")
                self.serverQueue.asyncAfter(deadline: .now() + 60) {
                    // retry after 1 second
                    self.connect()
                }
                
            case .cancelled:
                self.messageBoard.postTemporaryMessage("Connection was cancelled ? not retrying")
                break
                
            @unknown default:
                self.messageBoard.postTemporaryMessage("Incoming message was weird")
            }
        }
    }
    
    private func readNextMessage(_ connection: NWConnection) {
        // Read message encoded by the server. It contains two parts:
        //
        // - a 4-byte header (encoded in big endian) that gives the size of the rest of the message
        // - the actual JSON data itself

        let headerSize = MemoryLayout<UInt32>.size

        connection.receive(minimumIncompleteLength: headerSize, maximumLength: headerSize) { (data: Data?, _, _, error: NWError?) in
            if let error = error {
                self.messageBoard.postTemporaryMessage("Error reading frame header ? \(error)")
                connection.cancel()
                return
            }
            
            if let headerData = data {
                let frameSize = self.decodeFrameHeader(data: headerData)

                connection.receive(minimumIncompleteLength: frameSize, maximumLength: frameSize, completion: {  (data: Data?, _, _, error: NWError?) in

                    if let error = error {
                        self.messageBoard.postTemporaryMessage("Error reading frame contents ? \(error)")
                        connection.cancel()
                        return
                    }
                    
                    if let messageContents = data {
                        self.processFrameContents(data: messageContents)
                    }

                    self.readNextMessage(connection)
                })
            } else {
                self.readNextMessage(connection)
            }
        }
    }
    
    private func encodeFrameHeader(size: Int)  -> Data {
        // encode the frame header to 4 bytes big endian
        var frameSize = UInt32(size).bigEndian
        return Data(bytes: &frameSize, count: 4)
    }

    private func decodeFrameHeader(data: consuming Data) -> Int {
        // decodes the 4 bytes frame header (sent as big endian on the wire) to an Int
        var frameSize: UInt32 = 0
        _ = withUnsafeMutablePointer(to: &frameSize) { mutablePointer in
            data.copyBytes(to: UnsafeMutableBufferPointer(start: mutablePointer, count: MemoryLayout<UInt32>.size))
        }

        frameSize = NSSwapBigIntToHost(frameSize)
        
        return Int(frameSize)
    }

    private func processFrameContents(data: consuming Data) {
        // once we have the actual data for a frame, decode the JSON to a ServerMessage
        do {
            let message = try JSONDecoder().decode(ServerMessage.self, from: data)
            self.process(message: message)
            DispatchQueue.main.async {
                self.newMessageNotification?(message)
            }
        }
        catch let decodingErr {
            self.messageBoard.postTemporaryMessage("JSON decoding error: \(decodingErr)", duration: 5)
        }
    }

    public func sendMessage(message: consuming String) {
        guard let chatID = self.activeChatID else {
            return
        }
        self.send(.message(chatID: chatID, text: message))
    }
    
    public func send(_ command: consuming ClientCommand) {
        // Send a command to the server. It contains two parts:
        // - a 4-byte header (encoded in big endian) that gives the size of the rest of the message
        // - the actual JSON data itself
        
        print("AsdfasdfSDF")
        
        do {
            
            let jsonData = try JSONEncoder().encode(command)

            // 2. now that we have data, we need to know its size and prepare the frame header
            let headerData = encodeFrameHeader(size: jsonData.count)

            
            self.connection?.send(content: headerData, isComplete: true, completion: .contentProcessed({ error in
                if let error = error {
                    self.messageBoard.postTemporaryMessage("Error sending frame header ? \(error)")
                }
            }))
            
            self.connection?.send(content: jsonData, completion: .contentProcessed({ error in
                if let error = error {
                    self.messageBoard.postTemporaryMessage("Error sending frame contents ? \(error)")
                }
            }))
        } catch let err {
            self.messageBoard.postTemporaryMessage("Failed encoding JSON command ? \(err)")
        }
    }
    
    private func process(message: consuming ServerMessage) {
        self.messageBoard.postTemporaryMessage("Processing server message ? \(message)")
        switch message {

        case .connected:
            loggedIn = true

        case .disconnected:
            loggedIn = false

        case .chats(let chats):
            self.chats = chats.compactMap { $0 }
            self.activeChatID = chats.last?.id
            
        case .users(let users):
            users.forEach { user in
                //print(user)
            }
        case .message(let chatID, let text):
            let chat = self.chats.first(where: { $0.id == chatID })
            
            guard let chatUnwrapped = chat else {
                return
            }
            
            chatUnwrapped.messages.append(ChatMessage(sender: .sal, text: text))
        }
        
    }
    
    private func getTLSParameters(allowInsecure: Bool) -> NWParameters {
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
            
        }, self.serverQueue)
        
        return NWParameters(tls: options)
    }
}
