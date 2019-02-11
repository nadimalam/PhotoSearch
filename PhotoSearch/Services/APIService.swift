//
//  APIService.swift
//  PhotoSearch
//
//  Created by Nadim Alam on 16/01/2019.
//  Copyright © 2019 Nadim Alam. All rights reserved.
//

import UIKit

let apiKey = "96fa4468dfc2e94fcb17b3a12093b6f9"
let secretKey = "a49c978b3340caec"

class APIService {
    
    enum Error: Swift.Error {
        case unknownAPIResponse
        case generic
    }
    
    func searchAPIService(for searchTerm: String, completion: @escaping (Result<PhotoSearchResults>) -> Void) {
        
        guard let searchURL = searchURL(for: searchTerm) else {
            completion(Result.error(Error.unknownAPIResponse))
            return
        }
        
        let searchRequest = URLRequest(url: searchURL)
        
        URLSession.shared.dataTask(with: searchRequest) { (data, response, error) in
            if let error = error {
                DispatchQueue.main.async {
                    completion(Result.error(error))
                }
                return
            }
            
            guard
                let _ = response as? HTTPURLResponse,
                let data = data
                else {
                    DispatchQueue.main.async {
                        completion(Result.error(Error.unknownAPIResponse))
                    }
                    return
            }
            
            do {
                guard
                    let resultsDictionary = try JSONSerialization.jsonObject(with: data) as? [String: AnyObject],
                    let stat = resultsDictionary["stat"] as? String
                    else {
                        DispatchQueue.main.async {
                            completion(Result.error(Error.unknownAPIResponse))
                        }
                        return
                }
                
                switch (stat) {
                case "ok":
                    print("Results processed OK")
                case "fail":
                    DispatchQueue.main.async {
                        completion(Result.error(Error.generic))
                    }
                    return
                default:
                    DispatchQueue.main.async {
                        completion(Result.error(Error.unknownAPIResponse))
                    }
                    return
                }
                
                guard
                    let photosContainer = resultsDictionary["photos"] as? [String: AnyObject],
                    let photosReceived = photosContainer["photo"] as? [[String: AnyObject]]
                    else {
                        DispatchQueue.main.async {
                            completion(Result.error(Error.unknownAPIResponse))
                        }
                        return
                }
                
                let photos: [Photo] = photosReceived.compactMap { photoObject in
                    guard
                        let photoID = photoObject["id"] as? String,
                        let farm = photoObject["farm"] as? Int ,
                        let server = photoObject["server"] as? String ,
                        let secret = photoObject["secret"] as? String
                        else {
                            return nil
                    }
                    
                    let photo = Photo(photoID: photoID, farm: farm, server: server, secret: secret)
                    
                    guard
                        let url = photo.photoImageURL(),
                        let imageData = try? Data(contentsOf: url as URL)
                        else {
                            return nil
                    }
                    
                    if let image = UIImage(data: imageData) {
                        photo.thumbnail = image
                        return photo
                    } else {
                        return nil
                    }
                }
                
                let searchResults = PhotoSearchResults(searchTerm: searchTerm, searchResults: photos)
                DispatchQueue.main.async {
                    completion(Result.results(searchResults))
                }
            } catch {
                completion(Result.error(error))
                return
            }
        }.resume()
    }
    
    private func searchURL(for searchTerm:String) -> URL? {
        
        guard let escapedTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) else {
            return nil
        }
        
        let URLString = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&text=\(escapedTerm)&per_page=20&format=json&nojsoncallback=1"
        return URL(string:URLString)
    }
}
