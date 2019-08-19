//
//  Client.swift
//  VirtualTourist
//
//  Created by Hend  on 8/16/19.
//  Copyright © 2019 Hend . All rights reserved.
//

import Foundation
import UIKit

class FlickrClient : NSObject {
    
    // shared session
    var session = URLSession.shared

    override init() {
        super.init()
    }
    
    public func getImagesFromFlickrBySearch(latitude : Double, longitude : Double, completionHandler: @escaping (_ result: AnyObject?, _ error: NSError?) -> Void){
        let methodParameters = [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.BoundingBox: bboxString(latitude: latitude, longitude: longitude),
            Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback, Constants.FlickrParameterKeys.PhotosPerPage : Constants.FlickrParameterValues.PhotosPerPage
        ]
        
        self.taskForGETMethod(methodParameters as [String : AnyObject], withPageNumber: nil, latitude: latitude, longitude: longitude){(results, error) in
            
            guard (error == nil) else {
                print("\(error)")
                return
            }
            
            completionHandler(results, error)
        }
    }
    
    
    public func bboxString(latitude : Double, longitude : Double) -> String {
        // ensure bbox is bounded by minimum and maximums
        let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
        let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
        let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
        let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
        return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
    }
    
    // MARK: Flickr API
    
    private func taskForGETMethod
        (_ methodParameters: [String: AnyObject], withPageNumber: Int?, latitude : Double, longitude : Double, completionHandlerForGET: @escaping (_ result: AnyObject?, _ error: NSError?) -> Void) {
        
        // add the page to the method's parameters
        var methodParametersWithPageNumber = methodParameters
        if let pageNumber = withPageNumber{
            methodParametersWithPageNumber[Constants.FlickrParameterKeys.Page] = pageNumber as AnyObject?
        }
        
        // create session and request
        let session = URLSession.shared
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        // create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(_ error: String) {
                let userInfo = [NSLocalizedDescriptionKey : error]
                completionHandlerForGET(nil, NSError(domain: "taskForGETMethod", code: 1, userInfo: userInfo))
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Is "photos" key in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult)")
                return
            }
            
            if let pageNumber = withPageNumber{
                /* GUARD: Is the "photos" key in our result? */
                guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                    displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult)")
                    return
                }
                
                /* GUARD: Is the "photo" key in photosDictionary? */
                guard let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                    displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photosDictionary)")
                    return
                }
                
                
                    var Images = [UIImage]()
                    for photo in photosArray {
                        
                        /* GUARD: Does our photo have a key for 'url_m'? */
                        guard let imageUrlString = photo[Constants.FlickrResponseKeys.MediumURL] as? String else {
                            displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in photosArray")
                            return
                        }
                        
                        // if an image exists at the url, set the image and title
                        let imageURL = URL(string: imageUrlString)
                        if let imageData = try? Data(contentsOf: imageURL!) {
                            Images.append(UIImage(data: imageData)!)
                        } else {
                            displayError("Image does not exist at \(imageURL)")
                        }
                    }
                    completionHandlerForGET(Images as AnyObject, nil)
            }else{
                /* GUARD: Is "pages" key in the photosDictionary? */
                guard let totalPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                    displayError("Cannot find key '\(Constants.FlickrResponseKeys.Pages)' in \(photosDictionary)")
                    return
                }
                
                // pick a random page!
                let pageLimit = min(totalPages, 40)
                let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                self.taskForGETMethod(methodParameters as [String : AnyObject], withPageNumber: randomPage, latitude: latitude, longitude: longitude){(results, error) in
                    completionHandlerForGET(results, error)
                }
            }
        }
            
            
        
        // start the task!
        task.resume()
    }
    // FIX: For Swift 3, variable parameters are being depreciated. Instead, create a copy of the parameter inside the function.
    
    /*private func getImagesFromFlickrBySearch(_ methodParameters: [String: AnyObject], withPageNumber: Int, latitude : Double, longitude : Double) {
        
        // add the page to the method's parameters
        var methodParametersWithPageNumber = methodParameters
        methodParametersWithPageNumber[Constants.FlickrParameterKeys.Page] = withPageNumber as AnyObject?
        
        // create session and request
        let session = URLSession.shared
        let request = URLRequest(url: flickrURLFromParameters(methodParameters))
        
        // create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(_ error: String) {
                print(error)
            }
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Is the "photos" key in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photos)' in \(parsedResult)")
                return
            }
            
            /* GUARD: Is the "photo" key in photosDictionary? */
            guard let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                displayError("Cannot find key '\(Constants.FlickrResponseKeys.Photo)' in \(photosDictionary)")
                return
            }
            
            if photosArray.count == 0 {
                displayError("No Photos Found. Search Again.")
                return
            } else {
                for photo in photosArray {
                    
                    /* GUARD: Does our photo have a key for 'url_m'? */
                    guard let imageUrlString = photo[Constants.FlickrResponseKeys.MediumURL] as? String else {
                        displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in photosArray")
                        return
                    }
                    
                    // if an image exists at the url, set the image and title
                    let imageURL = URL(string: imageUrlString)
                    if let imageData = try? Data(contentsOf: imageURL!) {
                        
                    } else {
                        displayError("Image does not exist at \(imageURL)")
                    }
                }
            }
        }
        
        // start the task!
        task.resume()
    }*/
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String:AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
    
    // MARK: Shared Instance
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
}
