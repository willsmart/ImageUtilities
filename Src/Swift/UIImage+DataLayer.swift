//
//  UIImage+.swift
//  Synesthete
//
//  Created by Will Smart on 31/07/15.
//
//


import Foundation
import CoreImage
import AVFoundation
private typealias _CIImage = CIImage

private let s_defaultMask=UInt8(31)

private var s_madeDetector=false
private var s_detector:CIDetector?
private var s_maxPerDataBytes = 207
private var s_qrCompression = "Q"

private func deb(s:AnyObject) {print(s is String ? s as! String : "\(s)")}

public extension UIImage {
    public func decodedDataLayerAsString()->String? {
        if let d = decodedDataLayer() {
            return String(data: d, encoding: NSUTF8StringEncoding)
        }
        else {return nil}
    }
    
    
    public func decodedDataLayer()->NSData? {
        //let sz = CGSizeMake(max(size.width,size.height), max(size.width,size.height))
        if let (data,size) = pixelBytes() {
            return UIImage.dataLayerInImage(data, imageSize: size)
        }
        else {
            return nil
        }
    }
    
    
    public class func addDataLayerToImageData(imageData:NSMutableData, imageSize:CGSize, dataLayerData:NSData?=nil, data:NSData?=nil, dataString:String?=nil, pixelModulusOption:Int)->Bool {
        if let dataString = dataString {
            deb("Encode with string [\(dataString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))]: \(dataString)")
            return addDataLayerToImageData(imageData, imageSize:imageSize, dataLayerData: dataString.dataUsingEncoding(NSUTF8StringEncoding), pixelModulusOption:pixelModulusOption)
        }
        guard let dataLayerData = dataLayerData else {return false}
        
        return _addDataLayerToImageData(imageData, imageSize: imageSize, dataLayerData: dataLayerData, pixelModulusOptionIndex: Int32(pixelModulusOption))
    }
    
    
    public func copiedDataWithDataLayer(dataLayerData dataLayerData:NSData?=nil, data:NSData?=nil, string:String?=nil, pixelModulusOption:Int)->(NSMutableData,CGSize)? {
        if let (imgData,size) = pixelBytes() {
            if UIImage.addDataLayerToImageData(imgData, imageSize: size, dataLayerData:dataLayerData, data:data,dataString:string, pixelModulusOption:pixelModulusOption) {
                return (imgData,size)
            }
            else {return nil}
        }
        else {return nil}
    }
    
    public func encodeUsingDataLayer(dataLayerData dataLayerData:NSData?=nil, data:NSData?=nil, string:String?=nil, pixelModulusOption:Int)->UIImage? {
        if let (data,size) = copiedDataWithDataLayer(dataLayerData:dataLayerData, data:data, string:string, pixelModulusOption:pixelModulusOption) {
            return UIImage.imageFromData(data, size: size)
        }
        else {
            return nil
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    public func exportableDataLayerEncodedCopy(dataLayerData dataLayerData:NSData?=nil, data:NSData?=nil, string:String?=nil)->UIImage? {
        if let d = exportableDataLayerEncodedRepresentation(dataLayerData:dataLayerData, data:data, string:string) {
            return UIImage(data: d)
        }
        else {return nil}
    }
    
    public func exportableDataLayerEncodedRepresentation(dataLayerData dataLayerData:NSData?=nil, data:NSData?=nil, string:String?=nil, pixelModulusOption:Int?=nil)->NSData? {

        guard let pixelModulusOption = pixelModulusOption else {
            for pixelModulusOption in 0..<3 {
                if let rep = exportableDataLayerEncodedRepresentation(dataLayerData: dataLayerData, data: data, string: string, pixelModulusOption: pixelModulusOption) {
                    return rep
                }
            }
            return nil
        }
        
        print("\n\n\nWrite watermark (mod \(pixelModulusOption)....\n\n\n\n")

        let sz0 = CGSizeMake(self.size.width*self.scale, self.size.height*self.scale)
        let sz = CGSizeMake(
            min(sz0.width,1024*min(sz0.width/sz0.height,1)),
            min(sz0.height,1024*min(sz0.height/sz0.width,1))
        )
        
        let image:UIImage
    
        if let (imageData,imageSize) = scaledToSize(sz).JPGDistorted(0.1)?.0.pixelBytes() {
            UIImage.addDataLayerToImageData(imageData, imageSize: imageSize, dataLayerData: dataLayerData, data: data, dataString: string, pixelModulusOption:pixelModulusOption)
            if let im = UIImage.imageFromData(imageData, size: imageSize) {
                image = im
            }
            else {
                return nil
            }
        }
        else {
            return nil
        }

        let (_,representation) = image.JPGDistorted(1.0)!
        let (lqim,_) = image.JPGDistorted(0.4)!
        
        var ok=false
        if let _ = lqim.decodedDataLayer() {
            ok=true
        }
        else {
            print(" no data layer read back from image. Image must be too fussy")
        }
        
        return (ok ? representation : nil)
    }
}


