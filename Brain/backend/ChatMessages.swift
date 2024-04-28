import Foundation
import SwiftSoup

public enum Sender : String {
    case bot
    case user
}

public struct ChatMessage {
    let sender : Sender
    var content : String
    
    let id : UUID
    let datetime : Date

    //let searchItems : [SearchItem?]
    //let searchResults : [SearchResult?]

    //let searchItemTypes : [any SearchItem.Type] = [GoogleSearchItem.self, ChroniclingAmericaItem.self]

    init(_ content : String, sender : Sender) {
        self.sender = sender
        self.content = content

        self.id = UUID()
        self.datetime = Date()
        //self.searchItems = [nil]
        //self.searchResults = [nil]
    }


/*
    static func createSearchItems(doc : Document) throws -> [any SearchItem] {
        let content = try doc.text()

        let links = try content.extractLinks()

        //let items : [any SearchItem]

        let items = links.map{ GoogleSearchItem(webURL: URL(string: $0), thumbnailURL: nil) }

        for link in links {
            GoogleSearchItem(webURL: URL(string: link), thumbnailURL: nil)
        }
    }*/


}

