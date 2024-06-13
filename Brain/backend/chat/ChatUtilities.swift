//
//  MessageUtilities.swift
//  chatbot
//
//  Created by Owen O'Malley on 8/18/23.
//

import Foundation

extension String {
    func extractLinks() throws -> [Self] {
        let pattern = #"https?://\S+"#
        
        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
        
        let urls = matches.map { match in
            (self as NSString).substring(with: match.range)
        }
        
        return urls
    }
}
