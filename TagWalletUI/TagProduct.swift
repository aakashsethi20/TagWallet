//
//  TagProduct.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/23/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation
import UIKit

struct TagProduct: Codable {
    var productSeries: String
    var character: String
    var gameSeries: String
    var imageURL: String
    var name: String
    var type: String
    var head: String
    var tail: String
    var dumps: [TagDump]
    
    var cardNumber: String? = nil
    var imageAssetName: String? = nil
    var id: String { (head + tail).lowercased() }

    static let imageDataCache = NSCache<NSString, NSData>()
    
    func getImage(completion: @escaping (UIImage?) -> Void) {
        if let imageData = Self.imageDataCache.object(forKey: imageURL as NSString) {
            completion(UIImage(data: imageData as Data))
        } else if let url = URL(string: imageURL) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let imageData = data else { return }
                DispatchQueue.main.async {
                    Self.imageDataCache.setObject(imageData as NSData, forKey: self.imageURL as NSString)
                    completion(UIImage(data: imageData))
                }
            }.resume()
        }
    }
}

struct TagWallet: Codable {
    var tagProducts: [TagProduct]
    var staticKey: TagKey?
    var dataKey: TagKey?
}
