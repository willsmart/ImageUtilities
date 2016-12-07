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



public extension UIImage {
    public var pixelSize:CGSize {get {return CGSizeMake(size.width*scale, size.height*scale);}}
    
    public func scaledToSize(newSize:CGSize)->UIImage {
        let absSize = CGSizeMake(abs(newSize.width), abs(newSize.height))
        UIGraphicsBeginImageContextWithOptions(absSize, false, 1.0)
        if newSize.width<0 {
            if let ctxt = UIGraphicsGetCurrentContext() {
                CGContextScaleCTM(ctxt, -1, 1)
                CGContextTranslateCTM(ctxt, newSize.width, 0)
            }
        }
        if newSize.height<0 {
            if let ctxt = UIGraphicsGetCurrentContext() {
                CGContextScaleCTM(ctxt, 1, -1)
                CGContextTranslateCTM(ctxt, 0, newSize.height)
            }
        }
        drawInRect(CGRectMake(0, 0, abs(newSize.width), abs(newSize.height)))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }

    public func withAddedImage(image:UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        drawInRect(CGRectMake(0, 0, size.width, size.height))
        let imSz = CGSizeMake(min(size.width,image.size.width), image.size.height*min(1,size.width/image.size.width))
        image.drawInRect(CGRectMake((size.width-imSz.width)/2, imSz.height/2, imSz.width, imSz.height))
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resultImage!
    }

    private class var _completionKey:UnsafePointer<Void> {
        get {
            if (s_completionKey == nil) {
                s_completionKey = "__completion".asVoidPointerKey
            }
            return s_completionKey!
        }
    }
    private class var _dataKey:UnsafePointer<Void> {
        get {
            if (s_dataKey == nil) {
                s_dataKey = "__imageData".asVoidPointerKey
            }
            return s_dataKey!
        }
    }

    @objc public class func imageFromData(data:NSData?, size:CGSize) -> UIImage? {
        if (data == nil) {return nil}
        
        let bytesPerRow = Int(round(4*size.width))
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let colorSpaceRef = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue:CGImageAlphaInfo.PremultipliedLast.rawValue | CGBitmapInfo.ByteOrderDefault.rawValue)
        let renderingIntent = CGColorRenderingIntent.RenderingIntentDefault
        
        
        //let bytes = UnsafePointer<UInt8>(data!.bytes)
        print("Getting image from data (\(Int(round(size.width)))x\(Int(round(size.height)))) ", terminator: "")
        //for i in 0..<100 {print("\(i):\(bytes[i]),")}
        //println()

        let provider = (CGDataProviderCreateWithData(nil,data!.bytes,Int(round(size.height))*bytesPerRow) {a,b,c in})!
        let imageRef = CGImageCreate(Int(round(size.width)), Int(round(size.height)), bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, nil, false, renderingIntent)

        let ret:UIImage? = (imageRef == nil ? nil : UIImage(CGImage: imageRef!))
        set_fake_ivar(ret, UIImage._dataKey, data)
        return ret
     }

     public func pixelBytes(retSize:UnsafeMutablePointer<CGSize>) -> NSMutableData? {
        if let (d,sz) = pixelBytes() {
            retSize.memory = sz;
            return d;
        }
        else {
            retSize.memory = CGSizeMake(0, 0)
            return nil
        }
    }
    
     public func pixelBytes() -> (NSMutableData,CGSize)? {
        let count = Int(round(size.width))*Int(round(size.height))*4

        let ret = NSMutableData(length:count)
        if (ret == nil) {
            return nil
        }
        let imageRef = CGImage!
        let width = CGImageGetWidth(imageRef)
        let height = CGImageGetHeight(imageRef)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ptr = ret!.mutableBytes

        let context = CGBitmapContextCreate(ptr, width, height, 8, 4 * width, colorSpace, CGImageAlphaInfo.PremultipliedLast.rawValue | CGBitmapInfo.ByteOrderDefault.rawValue)!
        CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), imageRef)

        //let bytes = UnsafePointer<UInt8>(ptr)
        print("Wrote image to data (\(width)x\(height)) ", terminator: "")
        //for i in 0..<100 {print("\(i):\(bytes[i]),")}
        //println()

        return (ret!,CGSizeMake(CGFloat(width),CGFloat(height)))
    }
    

                    

    public class func load(path:String?=nil, url:NSURL?=nil ,pngData:NSData?=nil) -> (NSData?,UIImage?,AnyObject?) {
        let data:NSData?
        let metadata:AnyObject?
        let image:UIImage?
        if let path = path {
            data = NSData(contentsOfFile: path)
            metadata = (data == nil ? nil : metadataForPNG(pngData: data))
        }
        else if let url = url {
            data = NSData(contentsOfURL: url)
            metadata = (data == nil ? nil : metadataForPNG(pngData: data))
        }
        else if let pngData = pngData, source = CGImageSourceCreateWithData(pngData, nil) {
            data = pngData
            metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [NSObject:AnyObject]
        }
        else {
            data = nil
            metadata = nil
        }
        
        if let data = data {
            image = UIImage(data: data)
        }
        else {
            image = nil
        }
        return (data,image,metadata)
    }
    
    
    
    public class func metadataForPNG(path path:String?=nil, url:NSURL?=nil ,pngData:NSData?=nil) -> AnyObject? {
        if let path = path {
            let data = NSData(contentsOfFile: path)
            return(data == nil ? nil : metadataForPNG(pngData: data))
        }
        else if let url = url {
            let data = NSData(contentsOfURL: url)
            return(data == nil ? nil : metadataForPNG(pngData: data))
        }
        else if let pngData = pngData, source = CGImageSourceCreateWithData(pngData, nil) {
            if let d = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) {
                let pngd = (d as NSDictionary)[kCGImagePropertyPNGDictionary as NSString] as? NSDictionary
                let ret = pngd?[kCGImagePropertyPNGDescription as NSString]
                return ret
            }
            else {
                return nil
            }
        }
        else {
            return nil
        }
    }
    
    
    
    public func PNGRepresentationWithMetadata(metadata:AnyObject?)->NSData? {
        let metadata:CFDictionary? =  (metadata == nil ? nil : [
            kCGImagePropertyPNGDictionary as String : [
                kCGImagePropertyPNGDescription as String: metadata!
            ]
        ])
        let data = NSMutableData()
        let pngData = UIImagePNGRepresentation(self)
        if let source = CGImageSourceCreateWithData(pngData!, nil),
            UTI = CGImageSourceGetType(source),
            destination = CGImageDestinationCreateWithData(data, UTI, 1, nil) {
            CGImageDestinationAddImageFromSource(destination, source, 0, metadata)
            let success = CGImageDestinationFinalize(destination)
            return(success ? data : nil)
        }
        else {
            return nil
        }
    }
    
    
    
    public func writePNG(path:String,metadata:AnyObject?=nil)->Bool {
        let rep = PNGRepresentationWithMetadata(metadata)
        if (rep == nil) {
            return false
        }
        return rep!.writeToFile(path, atomically: true)
    }
    
    
    
    public func saveToCameraRoll(quality:CGFloat?=nil, metadata:[NSObject:AnyObject]?=nil, completion:((NSError?)->(Void))?=nil)->Bool {
        let data = (quality==nil ? UIImagePNGRepresentation(self) : UIImageJPEGRepresentation(self, quality!))
        if (data == nil) {return false}
        UIImage.saveToCameraRoll(data!, metadata: metadata, completion: completion)
        return true
    }
    
    public class func saveToCameraRoll(representation:NSData, metadata:[NSObject:AnyObject]?=nil, completion:((NSError?)->(Void))?=nil) {
        let library = ALAssetsLibrary()
        library.writeImageDataToSavedPhotosAlbum(representation, metadata: metadata, completionBlock: { (url:NSURL?, error:NSError?) in
            completion?(error)
        })
    }
           
    public func JPGDistorted(quality:CGFloat)->(UIImage,NSData)? {
        if let dat = UIImageJPEGRepresentation(self, quality), im = UIImage(data: dat) {
            return (im,dat);
        }
        else {return nil}
    }
    
  
}
