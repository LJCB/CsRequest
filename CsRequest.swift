//
//  CsRequest.swift
//  Farmapronto-Viper
//
//  Created by LuisCS on 06/04/20.
//  Copyright © 2020 CS. All rights reserved.
//

protocol NetworkSession {
  func api_request(parameters:[String:Any],headers:[String:String], method: HttpMethod, url:String, onSuccess: @escaping (Data, Any) -> Void, onFailure: @escaping ([String:Any],Int) -> Void)
}

import Foundation
import UIKit

class CsRequest {
  
  static let sharedInstance = CsRequest()
  private let session: NetworkSession
  var image_cache = NSCache<NSString, UIImage>()
  var obj_json: [String:Any] = [String:Any]()
  var obj_json_array: [[String:Any]] = [[String:Any]]()
  
  init(session: NetworkSession = URLSession.shared) {
    self.session = session
  }
    
  func api_request(parameters:[String:Any],headers:[String:String], method: HttpMethod, url:String, onSuccess: @escaping (Data, Any) -> Void, onFailure: @escaping ([String:Any],Int) -> Void){
    session.api_request(parameters: parameters, headers: headers, method: method, url: url, onSuccess: { (data_response, json) in
      onSuccess(data_response, json)
    }){ (json, status_code) in
      onFailure(json, status_code)
    }
  }
  
  func download_image(_ url_string: String, place_holder_image: UIImage?, in_image_view: UIImageView) {
    in_image_view.image = place_holder_image
    if let cachedImage = image_cache.object(forKey: NSString(string: url_string)) {
      in_image_view.image = cachedImage
      return
    }
    
    if let url = URL(string: url_string) {
      URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
        if error != nil {
          print("ERROR LOADING IMAGES FROM URL: \(String(describing: error))")
          DispatchQueue.main.async {
            in_image_view.image = place_holder_image ?? UIImage()
          }
          return
        }
        
        DispatchQueue.main.async {
          if let data = data {
            if let downloadedImage = UIImage(data: data) {
              self.image_cache.setObject(downloadedImage, forKey: NSString(string: url_string))
              in_image_view.image = downloadedImage
            }
          }
        }
      }).resume()
    }
  }
  
  func upload_image(parameters: [String:Any]?, paramName: String, fileName: String, image: UIImage, url: String, headers:[String:String], imageType: ImageType, onSuccess: @escaping ([String:Any],Int) -> Void, onFailure: @escaping ([String:Any],Int) -> Void) {
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
    
    if parameters != nil {
      for (key, value) in parameters! {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
      }
    }
    
    // Send a POST request to the URL, with the data we created earlier
    session.uploadTask(with: urlRequest, from: data, completionHandler: { responseData, response, error in
      let httpStatusCode = response as? HTTPURLResponse ?? nil
      guard let content = responseData else {
        DispatchQueue.main.async {
          onFailure(["":""], httpStatusCode?.statusCode ?? 0)
        }
        return
      }
      
      guard let json = (try? JSONSerialization.jsonObject(with: content, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any] else {
        DispatchQueue.main.async {
          onFailure(["":""], httpStatusCode?.statusCode ?? 0)
        }
        return
      }
      
      
      if httpStatusCode?.statusCode == 200{
        DispatchQueue.main.async {
          onSuccess(json,httpStatusCode?.statusCode ?? 0)
        }
      }else{
        DispatchQueue.main.async {
          onFailure(json, httpStatusCode?.statusCode ?? 0)
        }
      }
    }).resume()
  }
}

extension URLSession: NetworkSession {
  func api_request(parameters:[String:Any],headers:[String:String], method: HttpMethod, url:String, onSuccess: @escaping (Data, Any) -> Void, onFailure: @escaping ([String:Any],Int) -> Void) {
    
    var obj_json = [String:Any]()
    var obj_json_array = [[String:Any]]()
    
    if let url = URL(string: url){
      var urlRequest = URLRequest(url: url)
      urlRequest.httpMethod = method.rawValue
      urlRequest.allHTTPHeaderFields = headers
      
      if !parameters.isEmpty{
        urlRequest.httpBody = getPostString(params: parameters).data(using: .utf8)
      }
      
      let task = dataTask(with: urlRequest) { data, response, error in
        let httpStatusCode = response as? HTTPURLResponse ?? nil
        guard let content = data else {
          DispatchQueue.main.async {
            onFailure(["":""], httpStatusCode?.statusCode ?? 0)
          }
          return
        }
        
        if let json = (try? JSONSerialization.jsonObject(with: content, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: Any]{
          obj_json = json
        }else{
          if let json = (try? JSONSerialization.jsonObject(with: content, options: JSONSerialization.ReadingOptions.mutableContainers)) as? [[String: Any]]{
            obj_json_array = json
          }else{
            obj_json = ["": ""]
            obj_json_array = [["":""]]
          }
        }
        
        if httpStatusCode?.statusCode == 200{
          DispatchQueue.main.async {
            if obj_json_array.count == 0{
              onSuccess(content, obj_json)
            }else{
              onSuccess(content, obj_json_array)
            }
          }
        }else{
          DispatchQueue.main.async {
            onFailure(obj_json,httpStatusCode?.statusCode ?? 0)
          }
        }
      }
      task.resume()
    }else{
      onFailure(["":""], 0)
    }
  }
  
  func getPostString(params:[String:Any]) -> String{
    var data = [String]()
    for(key, value) in params{
      if let array = value as? [Int]{
        for array_value in array{
          print("parametro a agregar como arreglo: \(key)[]=\(array_value)")
          data.append(key + "[]=\(array_value)")
        }
      }else{
        data.append(key + "=\(value)")
      }
    }
    return data.map { String($0) }.joined(separator: "&")
  }
}
