//
//  UIImage+.swift
//  Synesthete
//
//  Created by Will Smart on 31/07/15.
//
//

import Foundation
import ImageIO
import AssetsLibrary

private let s_idmark:UInt64 = 0x7fde912826daf760
private var s_completionKey:UnsafePointer<Void>?
private var s_dataKey:UnsafePointer<Void>?



public class URLLoadHandler : NSObject, NSURLConnectionDataDelegate {
    public var completion:(data:NSData?, error:NSError?)->(Void)
    public init(completion:(data:NSData?, error:NSError?)->(Void)) {
        self.completion = completion
    }
    
    public var data:NSMutableData?
    
    @objc public func connectionDidFinishLoading(connection: NSURLConnection) {
        completion(data:data,error:nil)
    }
    
    @objc public func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        completion(data:data,error:error)
    }
    
    @objc public func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        data = NSMutableData()
    }

    @objc public func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.data?.appendData(data)
    }
}

public class UIImageLoadHandler {
    public var loadHandler:URLLoadHandler
    public init(completion:(image:UIImage?,error:NSError?)->(Void)) {
        loadHandler = URLLoadHandler(completion: {(data:NSData?,error:NSError?) in
            let image:UIImage?
            if let data = data {
                image = UIImage(data:data)
            }
            else {image = nil}
            completion(image:image,error:error)
        })
    }
}

private var s_currentNSURLConnections=[NSURLConnection]()

public extension NSURL {
    public func load(completion:(data:NSData?,error:NSError?)->(Void))->Bool {
        let req = NSURLRequest(URL: self)
        if let c = NSURLConnection(request: req, delegate: URLLoadHandler(completion: {data, error in
            objc_sync(NSURL.self){
                s_currentNSURLConnections = s_currentNSURLConnections.filter{$0.originalRequest !== req}
            }
            completion(data:data, error:error)
        })) {
            objc_sync(NSURL.self){
                s_currentNSURLConnections.append(c)
            }
            return true
        }
        else {
            completion(data:nil,error:nil)
            return false
        }
    }
    public func uncachedLoad(timeout:NSTimeInterval, completion:(data:NSData?,error:NSError?)->(Void))->Bool {
        let req = NSURLRequest(URL: self, cachePolicy: .ReloadIgnoringCacheData, timeoutInterval: timeout)
        if let c = NSURLConnection(request: req, delegate: URLLoadHandler(completion: {data, error in
            objc_sync(NSURL.self){
                s_currentNSURLConnections = s_currentNSURLConnections.filter{$0.originalRequest !== req}
            }
            completion(data:data, error:error)
        })) {
            objc_sync(NSURL.self){
                s_currentNSURLConnections.append(c)
            }
            return true
        }
        else {
            completion(data:nil,error:nil)
            return false
        }
    }
}

public extension UIImage {
    public class func fromURL(url:NSURL, completion:(image:UIImage?,error:NSError?)->(Void))->Bool {
        return url.load { data, error in
            let image:UIImage?
            if let data = data {
                image = UIImage(data:data)
            }
            else {image = nil}
            completion(image:image,error:error)
        }
    }

  
}