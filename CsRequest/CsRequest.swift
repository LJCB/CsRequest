//
//  CsRequest.swift
//  CsRequest
//
//  Created by Luis J. Capistran on 6/13/19.
//  Copyright © 2019 CSGroup. All rights reserved.
//

import UIKit
import AVFoundation

public var imageCache = NSCache<NSString, UIImage>()

open class CsRequest: NSObject {
  public enum HttpMethod: String{
    case DELETE = "DELETE"
    case POST = "POST"
    case GET = "GET"
    case PUT = "PUT"
  }
  
  public enum ImageType {
    case png
    case jpeg
  }
  
  open class func getPostString(params:[String:Any]) -> String{
    var data = [String]()
    for(key, value) in params{
      data.append(key + "=\(value)")
    }
    return data.map { String($0) }.joined(separator: "&")
  }
  
  open class func makeRequest(parameters:[String:Any],headers:[String:String], method: HttpMethod, url:String, onSuccess: @escaping ([String:Any],Int) -> Void, onFailure: @escaping ([String:Any],Int) -> Void){
    
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config)
    
    if let url = URL(string: url){
      var urlRequest = URLRequest(url: url)
      urlRequest.httpMethod = method.rawValue
      urlRequest.allHTTPHeaderFields = headers
      
      if !parameters.isEmpty{
        urlRequest.httpBody = getPostString(params: parameters).data(using: .utf8)
      }
      
      let task = session.dataTask(with: urlRequest) { data, response, error in
        guard let content = data else {
          onFailure(["":""], 0)
          return
        }
        guard let json = (try? JSONSerialization.jsonObject(with: content, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] else {
          onFailure(["":""], 0)
          return
        }
        
        let httpStatusCode = response as? HTTPURLResponse ?? nil
        if httpStatusCode?.statusCode == 200{
          onSuccess(json,httpStatusCode?.statusCode ?? 0)
        }else{
          onFailure(json,httpStatusCode?.statusCode ?? 0)
        }
      }
      task.resume()
    }else{
      onFailure(["":""], 1)
    }
  }
  
  open class func uploadImage(paramName: String, fileName: String, image: UIImage, url: String, headers:[String:String], imageType: ImageType, onSuccess: @escaping ([String:Any],Int) -> Void, onFailure: @escaping ([String:Any],Int) -> Void) {
    let url = URL(string: url)
    
    //get mime from image
    var mimetype = "image/png" // default
    if imageType == .jpeg {
      mimetype = "image/jpeg"
    }
    
    // generate boundary string using a unique per-app string
    let boundary = UUID().uuidString
    let session = URLSession.shared
    // Set the URLRequest to POST and to the specified URL
    var urlRequest = URLRequest(url: url!)
    urlRequest.httpMethod = "POST"
    
    // Set Content-Type Header to multipart/form-data, this is equivalent to submitting form data with file upload in a web browser
    // And the boundary is also set here
    urlRequest.allHTTPHeaderFields = headers
    urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    var data = Data()
    
    // Add the image data to the raw http request data
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"\(paramName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
    if imageType == .jpeg {
      data.append(image.jpegData(compressionQuality: 0.6)!)
    }else{
      data.append(image.pngData()!)
    }
    
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    
    // Send a POST request to the URL, with the data we created earlier
    session.uploadTask(with: urlRequest, from: data, completionHandler: { responseData, response, error in
      guard let content = responseData else {
        onFailure(["":""], 0)
        return
      }
      
      guard let json = (try? JSONSerialization.jsonObject(with: content, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] else {
        onFailure(["":""], 0)
        return
      }
      
      let httpStatusCode = response as? HTTPURLResponse ?? nil
      if httpStatusCode?.statusCode == 200{
        onSuccess(json,httpStatusCode?.statusCode ?? 0)
      }else{
        onFailure(json,httpStatusCode?.statusCode ?? 0)
      }
    }).resume()
  }
  
  open class func downloadImage(_ URLString: String, placeHolder: UIImage?, inImageView: UIImageView) {
    inImageView.image = placeHolder
    if let cachedImage = imageCache.object(forKey: NSString(string: URLString)) {
      inImageView.image = cachedImage
      return
    }
    
    if let url = URL(string: URLString) {
      URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
        //print("RESPONSE FROM API: \(response!)")
        if error != nil {
          print("ERROR LOADING IMAGES FROM URL: \(String(describing: error))")
          DispatchQueue.main.async {
            inImageView.image = placeHolder ?? UIImage()
          }
          return
        }
        
        DispatchQueue.main.async {
          if let data = data {
            if let downloadedImage = UIImage(data: data) {
              imageCache.setObject(downloadedImage, forKey: NSString(string: URLString))
              inImageView.image = downloadedImage
            }
          }
        }
      }).resume()
    }
  }
}
