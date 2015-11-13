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
private var s_maxPerQRBytes = 207
private var s_qrCompression = "Q"

private func deb(s:AnyObject) {print(s is String ? s as! String : "\(s)")}

public extension UIImage {
    class func makeQRCodeDetector(ctxt:CIContext?=nil) -> CIDetector? {
        if !s_madeDetector {
            s_madeDetector = true
            let ctxt = CIContext(options: nil)
//            let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
            s_detector = CIDetector(ofType: CIDetectorTypeQRCode, context: ctxt, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            if s_detector == nil {
                print("Failed to make high quality qr code detector")
                s_detector = CIDetector(ofType: CIDetectorTypeQRCode, context: ctxt, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
                if s_detector == nil {
                    print("Failed to make low quality qr code detector")
                    s_detector = CIDetector(ofType: CIDetectorTypeQRCode, context: ctxt, options: nil)
                    if s_detector == nil {
                        print("Failed to make qr code detector")
                    }
                }
            }
        }
        return s_detector
    }
    
    
    /*
    var qrdecodedData:NSData? {
        get {return (s_detector == nil ? CGImage?.qrdecodedData : CIImage_triesHarder?.qrdecodedData)}
    }
    var qrdecodedString:String? {
        get {return  (s_detector == nil ? CGImage?.qrdecodedString : CIImage_triesHarder?.qrdecodedString)}
    }*/
    var qrdecodedData:NSData? {
        get {return CGImage?.qrdecodedData}
    }
    var qrdecodedString:String? {
        get {return CGImage?.qrdecodedString}
    }

    var qrdecodedDataLayer:NSData? {
        get {return qrdecodedDataLayer()}
    }
    func qrdecodedDataLayer(rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->NSData? {
        return dataLayerCopy(rect,mask:mask)?.qrdecodedData
    }
    var qrdecodedDataLayerAsString:String? {
        get {return qrdecodedDataLayerAsString()}
    }
    func qrdecodedDataLayerAsString(rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->String? {
        return dataLayerCopy(rect,mask:mask)?.qrdecodedString
    }
    
    class func qrencode(data data:NSData?=nil, string:String?=nil,scale:CGSize = CGSizeMake(1, 1), size:CGSize?=nil, eachScale:CGSize=CGSizeMake(1,1), pad:Bool = true) -> UIImage? {
        if let string = string {
            deb("QREncode with string: \(string)")
            return qrencode(data: string.dataUsingEncoding(NSUTF8StringEncoding), scale: scale, size: size)
        }
        guard let
            data = data,
            compressedData = data.alphaNumZipEncode().dataUsingEncoding(NSISOLatin1StringEncoding),
            filter = CIFilter(name: "CIQRCodeGenerator")
            else {return nil}
        
        
        deb("QREncode with data(uncompressed): \(data)\n   (compressed): \(compressedData)")
        var imgs = [_CIImage]()
        let side = Int(ceil(sqrt(Double(compressedData.length)/Double(s_maxPerQRBytes))))
        for y in 0..<side {
            for x in 0..<side {
                let bi = s_maxPerQRBytes*(x+y*side)
                if (pad || bi<compressedData.length) {
                    let d:NSData
                    if (bi>=compressedData.length) {
                        d = NSMutableData(length: s_maxPerQRBytes)!
                    }
                    else if (compressedData.length-bi>=s_maxPerQRBytes) {
                        d=compressedData.subdataWithRange(NSMakeRange(bi, s_maxPerQRBytes))
                    }
                    else if (pad) {
                        let md = NSMutableData(length: s_maxPerQRBytes)!
                        memcpy(md.mutableBytes,compressedData.bytes,compressedData.length-bi)
                        d = md
                    }
                    else {
                        d=compressedData.subdataWithRange(NSMakeRange(bi, compressedData.length-bi))
                    }
                    
                    //deb("   subdata at byte \(bi): \(d)")
                    filter.setValue(d, forKey: "inputMessage")
                    filter.setValue(s_qrCompression, forKey:"inputCorrectionLevel")
                    guard let img = filter.outputImage else {return nil}
                    imgs.append(img)
                }
                else {break}
            }
        }
        deb("   qrencoded ok")
        return UIImage.nonInterpolatedImageGrid(ciImages: imgs, scale: scale, size: size, eachScale:CGSizeMake(0.9, 0.9))
    }


    class func addQRLayerToImageData(imageData:NSMutableData, imageSize:CGSize, data:NSData?=nil, dataString:String?=nil, rect:CGRect?=nil, mask:UInt8 = s_defaultMask) {
        let rect = (rect == nil ? CGRectMake(0, 0, imageSize.width, imageSize.height) : rect!)
        let toN = imageData.length
        let q1 = (mask+1)/4, q3 = q1*3
        let dataImg = qrencode(data:data, string:dataString, size: rect.size, eachScale: CGSizeMake(1, 1))
        if let (d,dsize) = dataImg?.pixelBytes() {
            let fromN = d.length
            let fromb = UnsafePointer<UInt8>(d.bytes), tob = UnsafeMutablePointer<UInt8>(imageData.mutableBytes)
            for y in 0..<Int(round(dsize.height)) {
                let _toi = ((y+Int(round(rect.origin.y)))*Int(round(imageSize.width))+Int(round(rect.origin.x)))*4
                let fromi = (y*Int(round(imageSize.width)))*4
                let N = min(toN-_toi,min(fromN-fromi,Int(round(dsize.width))*4))
                let df = fromi-_toi
                for toi in _toi.stride(to: _toi+N, by: 4) {
                    tob[toi]=(tob[toi] & ~mask) | (fromb[toi+df]<0x80 ? q1 : q3)
                    tob[toi+1]=(tob[toi+1] & ~mask) | (fromb[toi+df]<0x80 ? q1 : q3)
                    tob[toi+2]=(tob[toi+2] & ~mask) | (fromb[toi+df]<0x80 ? q1 : q3)
                }
            }
        }
    }
    
    
    func copiedDataWithQRData(data data:NSData?=nil, string:String?=nil, rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->(NSMutableData,CGSize)? {
        if let (imgData,size) = pixelBytes() {
            UIImage.addQRLayerToImageData(imgData, imageSize: size, data:data, dataString:string, rect: rect, mask: mask)
            return (imgData,size)
        }
        else {return nil}
    }
    
    func qrencodeUsingDataLayer(data data:NSData?=nil, string:String?=nil, rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->UIImage? {
        if let (data,size) = copiedDataWithQRData(data:data, string:string, rect: rect, mask: mask) {
            return UIImage.imageFromData(data, size: size)
        }
        else {
            return nil
        }
    }
    
    class func copiedDataLayerData(imageData:NSData, imageSize:CGSize, rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->(NSMutableData,CGSize) {
        let rect = (rect == nil ? CGRectMake(0, 0, imageSize.width, imageSize.height) : rect!)
        let toN = imageData.length
        let q1 = Int((mask+1)/4), q2 = q1*2, q3 = q1*3
        let d = NSMutableData(length: Int(round(rect.size.width))*Int(round(rect.size.height))*4)!

        let fromN = d.length
        let fromb = UnsafePointer<UInt8>(imageData.bytes), tob = UnsafeMutablePointer<UInt8>(d.mutableBytes)
        for y in 0..<Int(round(rect.size.height)) {
            let fromi = ((y+Int(round(rect.origin.y)))*Int(round(imageSize.width))+Int(round(rect.origin.x)))*4
            let _toi = (y*Int(round(imageSize.width)))*4
            let N = min(toN-_toi,min(fromN-fromi,Int(round(rect.size.width))*4))
            let df = fromi-_toi
            for toi in _toi.stride(to: _toi+N, by: 4) {
                let r = max(0,min(0xff,abs(abs(Int(fromb[toi+df]&mask)-q3)-q2)*0xff/q2))
                tob[toi]=UInt8(r)
                let g = max(0,min(0xff,abs(abs(Int(fromb[toi+df+1]&mask)-q3)-q2)*0xff/q2))
                tob[toi+1]=UInt8(g)
                let b = max(0,min(0xff,abs(abs(Int(fromb[toi+df+2]&mask)-q3)-q2)*0xff/q2))
                tob[toi+2]=UInt8(b)
                tob[toi+3]=0xff
            }
        }
        return (d,rect.size)
    }
    
    func copiedDataLayerData(rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->(NSMutableData,CGSize)? {
        let sz = CGSizeMake(max(size.width,size.height), max(size.width,size.height))
        if let (data,size) = scaledToSize(sz).pixelBytes() {
            return UIImage.copiedDataLayerData(data, imageSize: size, rect: rect, mask: mask)
        }
        else {
            return nil
        }
    }
    
    func dataLayerCopy(rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->UIImage? {
        if let (data,size) = copiedDataLayerData(rect,mask:mask) {
            let im=UIImage.imageFromData(data, size: size)
            //im?.saveToCameraRoll()
            return im
        }
        else {
            return nil
        }
    }
    
    
    
    func exportableQREncodedCopy(string string:String, rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->UIImage? {
        if let d = exportableQREncodedRepresentation(string:string,rect:rect,mask:mask) {
            return UIImage(data: d)
        }
        else {return nil}
    }
    
    func exportableQREncodedRepresentation(string string:String, rect:CGRect?=nil, mask:UInt8 = s_defaultMask)->NSData? {
        var representation:NSData?

        print("\n\n\nWrite watermark....\n\n\n\n")

        let sz0 = CGSizeMake(self.size.width*self.scale, self.size.height*self.scale)
        let sz = CGSizeMake(
            min(sz0.width,1024*min(sz0.width/sz0.height,1)),
            min(sz0.height,1024*min(sz0.height/sz0.width,1))
        )
        var image = scaledToSize(sz)
        for quality:CGFloat in [0.5,0.3,0.1] {
            let (im,imData) = image.JPGDistorted(quality)!
            if (imData.length <= 5<<20) {
                image = im
                break
            }
        }
    
        if let (data,size) = image.pixelBytes() {
            UIImage.addQRLayerToImageData(data, imageSize: size, dataString: string, rect: rect, mask: mask)
            if let im = UIImage.imageFromData(data, size: size) {
                image = im
            }
            else {
                return nil
            }
        }
        else {
            return nil
        }
        
        //let d = image.watermarkDictionary;
        //print(d)
        
        //println("\n\n\nCheck perfect....\n\n\n\n")
        //let d = mimage!.watermarkDictionary
        /*
        println("\n\n\nCheck converted 1.0....\n\n\n\n")
        var dat = UIImageJPEGRepresentation(mimage, 1.0);
        var jimage = UIImage(data: dat);
        var jd = jimage!.watermarkDictionary
        
        println("\n\n\nCheck converted 0.9....\n\n\n\n")
        dat = UIImageJPEGRepresentation(mimage, 0.9);
        jimage = UIImage(data: dat);
        jd = jimage!.watermarkDictionary
        
        println("\n\n\nCheck converted 0.5....\n\n\n\n")
        dat = UIImageJPEGRepresentation(mimage, 0.5);
        jimage = UIImage(data: dat);
        jd = jimage!.watermarkDictionary
        
        println("\n\n\nCheck converted 0.2....\n\n\n\n")
        dat = UIImageJPEGRepresentation(mimage, 0.2);
        jimage = UIImage(data: dat);
        jd = jimage!.watermarkDictionary
        
        */
        
        /*
        let fm = NSFileManager.defaultManager()
        let base = App.documentsFolder
        var fn = "Snapshot_\(nextSnapIndex).png"
        while (fm.fileExistsAtPath(base.stringByAppendingPathComponent(fn))) {
            fn = "Snapshot_\(++nextSnapIndex).png"
        }
        mimage!.writePNG(base.stringByAppendingPathComponent(fn), metadata:metadata)
        */

        for quality:CGFloat in [0.9,0.8,0.7,0.6,0.5,0.4,0.3,0.2,0.1] {
            let (im,imData) = image.JPGDistorted(quality)!
            if (imData.length <= 5<<20) {
                image = im
                representation = imData
                break
            }
        }
        
        if let r = representation, im = UIImage(data:r) {
            let s = im.qrdecodedDataLayer(rect, mask: mask)
            print(s)
        }
        
        return representation
    }
    
    public class func nonInterpolatedImageGrid(ciImages ciImages:[_CIImage]?=nil, cgImages:[CGImageRef]?=nil, scale:CGSize = CGSizeMake(1, 1), size:CGSize?=nil, eachScale:CGSize=CGSizeMake(1,1)) -> UIImage? {
        if let ciImages = ciImages {
            let ctxt = CIContext(options: nil)
            return nonInterpolatedImageGrid(cgImages:ciImages.map{ctxt.createCGImage($0, fromRect: $0.extent)}, scale:scale, size:size, eachScale:eachScale)
        }
        else if let cgImages = cgImages {
            if cgImages.count == 0 {return nil}
            
            let eachSz = cgImages.reduce(CGSizeMake(1, 1)){sz,img -> CGSize in
                CGSizeMake(max(sz.width,CGFloat(CGImageGetWidth(img))),max(sz.height,CGFloat(CGImageGetHeight(img))))
            }
            
            let side = Int(ceil(sqrt(Double(cgImages.count))))
            let totSize = CGSizeMake(eachSz.width*CGFloat(side), eachSz.height*CGFloat(side))
            
            let size = (size != nil ? size! : CGSizeMake(totSize.width*scale.width,totSize.height*scale.height))
            
            UIGraphicsBeginImageContext(size)
            let context = UIGraphicsGetCurrentContext()
            CGContextSetInterpolationQuality(context, .None);
            var x=0,y=0
            let bounds = CGContextGetClipBoundingBox(context)
            let r = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width/CGFloat(side), bounds.size.height/CGFloat(side))
            for img in cgImages {
                CGContextSaveGState(context)
                let r2 = CGRectMake(r.origin.x+r.size.width*CGFloat(x), r.origin.y+r.size.height*CGFloat(y), r.size.width, r.size.height)
                let r3 = CGRectMake(r.origin.x+r.size.width*(CGFloat(x)+0.5*(1-eachScale.width)), r.origin.y+r.size.height*(CGFloat(y)+0.5*(1-eachScale.height)), r.size.width*eachScale.width, r.size.height*eachScale.height)
                CGContextClipToRect(context, r2)
                CGContextDrawImage(context, r3, img)
                CGContextRestoreGState(context)
                x++
                if (x==side) {x = 0; y++}
            }
            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            deb("encoded image with size:\(scaledImage.size)x\(scaledImage.scale)")
            return scaledImage
        }
        else {return nil}
    }
    
    
    var CIImage_triesHarder:_CIImage? {
        get {
            if let ret = CIImage {
                return ret
            }
            else if let cg = CGImage {
                return _CIImage(CGImage: cg)
            }
            else {return nil}
        }
    }
    
}

public extension _CIImage {
    public func nonInterpolatedUIImage(scale scale:CGSize = CGSizeMake(1, 1), size:CGSize?=nil) -> UIImage {
        return UIImage.nonInterpolatedImageGrid(ciImages:[self], scale: scale, size: size)!
    }


    func gridElement(pos pos:CGPoint,side:CGSize) ->_CIImage {
        let extent = self.extent
        return imageByCroppingToRect(CGRectMake(
            extent.origin.x+extent.size.width*pos.x/side.width,
            extent.origin.y+extent.size.height*(side.height-1-pos.y)/side.height,
            extent.size.width/side.width,
            extent.size.height/side.height
        ))
    }
    
    var qrdecodedString:String? {
        get {
            if let d = qrdecodedData {
                let ret = String(data: d, encoding: NSUTF8StringEncoding)
                deb("qrdecode to string: \(ret)\n")
                return ret
            }
            else {return nil}
        }
    }
    
    var qrdecodedData:NSData? {
        get {
            var data:NSMutableData?
            for side in 2.stride(through: 1, by: -1) {
                deb("qrdecode with side: \(side)")
                for y in 0..<side {
                    for x in 0..<side {
                        let img = gridElement(pos: CGPointMake(CGFloat(x), CGFloat(y)), side: CGSizeMake(CGFloat(side),CGFloat(side)))
                        if let el = img.qrdecode().first {
                            let d = el.string.dataUsingEncoding(NSISOLatin1StringEncoding)!
                            if data == nil {data = d.mutableCopy() as? NSMutableData}
                            else {data?.appendData(d)}
                        }
                        else {break}
                    }
                    if (data == nil) {break}
                }
                if let compressedData = data {
                    deb("qrdecoded data (compressed): \(compressedData)")
                    let compressedString = String(data: compressedData, encoding: NSISOLatin1StringEncoding)
                    deb("qrdecoded string (compressed): \(compressedString)")
                    let ret = compressedString?.alphaNumDecodeAsData()
                    deb("qrdecoded data (uncompressed): \(ret)")
                    return ret
                }
            }
            deb("qrdecode failed")
            return nil
        }
    }
   
    
    func qrdecode() -> [(string: String, (topLeft:CGPoint, topRight:CGPoint, bottomLeft:CGPoint, bottomRight:CGPoint))] {
        guard let detector = s_detector else {
            deb("can't qrdecode image since there is no available detector")
            return []
        }
        
        
        //UIImage(CGImage: CIContext().createCGImage(self, fromRect: extent)).saveToCameraRoll()
        
        deb("qrdecoding ciimage \(extent)")
        var ret=[(string: String, (topLeft:CGPoint, topRight:CGPoint, bottomLeft:CGPoint, bottomRight:CGPoint))]()
        let features = detector.featuresInImage(self)
        for feature in features as! [CIQRCodeFeature] {
            ret.append((string:feature.messageString, (topLeft:feature.topLeft, topRight: feature.topRight,
            bottomLeft: feature.bottomLeft, bottomRight: feature.bottomRight)))
            deb("qrdecoded : \(feature.messageString)")
        }
        return ret
    }
}




public extension CGImage {
    var extent:CGRect {
        get{return CGRectMake(0,0,CGFloat(CGImageGetWidth(self)), CGFloat(CGImageGetHeight(self)))}
    }
    
    func gridElement(pos pos:CGPoint,side:CGSize) ->CGImage? {
        let extent = self.extent
        let r = CGRectMake(
            extent.origin.x+extent.size.width*pos.x/side.width,
            extent.origin.y+extent.size.height*pos.y/side.height,
            extent.size.width/side.width,
            extent.size.height/side.height
        )
        print(r)
        return CGImageCreateWithImageInRect(self, r)
    }
    
    var qrdecodedString:String? {
        get {
            if let d = qrdecodedData {
                let ret = String(data: d, encoding: NSUTF8StringEncoding)
                deb("qrdecode to string: \(ret)\n")
                return ret
            }
            else {return nil}
        }
    }
    
    var qrdecodedData:NSData? {
        get {
            var data:NSMutableData?
            for side in 8.stride(through: 1, by: -1) {
                deb("qrdecode with side: \(side)")
                for y in 0..<side {
                    for x in 0..<side {
                        let img = gridElement(pos: CGPointMake(CGFloat(x), CGFloat(y)), side: CGSizeMake(CGFloat(side),CGFloat(side)))
                        //async{UIImage(CGImage: img!).saveToCameraRoll()}
                        if let el = img?.qrdecode().first {
                            deb("ok")
                            let d = el.dataUsingEncoding(NSISOLatin1StringEncoding)!
                            if data == nil {data = d.mutableCopy() as? NSMutableData}
                            else {data?.appendData(d)}
                        }
                        else {
                            deb("no")
                            break
                        }
                    }
                    if (data == nil) {break}
                }
                if let compressedData = data {
                    deb("qrdecoded data (compressed): \(compressedData)")
                    let compressedString = String(data: compressedData, encoding: NSISOLatin1StringEncoding)
                    deb("qrdecoded string (compressed): \(compressedString)")
                    let ret = compressedString?.alphaNumDecodeAsData()
                    deb("qrdecoded data (uncompressed): \(ret)")
                    return ret
                }
            }
            deb("qrdecode failed")
            return nil
        }
    }
   
    
    func qrdecode() -> [String] {
        deb("qrdecoding cgimage \(extent)")
        let ret = ZBar.featuresInImage(self)
        return ret
    }
}




extension ZBarSymbolSet: SequenceType {
    public func generate() -> NSFastGenerator {
        return NSFastGenerator(self)
    }
}

class ZBar {
    static var s_instance:ZBar?
    class var instance:ZBar {get {
    if let ret = s_instance {return ret}
    else {
        s_instance = ZBar()
        return s_instance!
    }
    }}
    var scanner:ZBarImageScanner
    init() {
        scanner = ZBarImageScanner()
    }
    
    class func featuresInImage(image:CGImage)->[String] {
        instance.scanner.scanImage(ZBarImage(CGImage: image))
        let ret = instance.scanner.results.map{(o) -> String in
            guard let sym = o as? ZBarSymbol else {return ""}
            return sym.data
        }
        return ret
    }
}

