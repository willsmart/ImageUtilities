
public func objc_sync(object:AnyObject!,block:((Void)->(Void))) {
    objc_sync_enter(object)
    block()
    objc_sync_exit(object)
}
public func async(sec:CFTimeInterval?=nil, block:((Void)->(Void))) {
    if let sec = sec {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,  Int64(sec * CFTimeInterval(NSEC_PER_SEC))), dispatch_get_main_queue(), block);
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block)
    }
}


public extension String {
    public func convertRange(nsrange:NSRange)->Range<String.Index>? {
        return nsrange.location<0 || nsrange.location+nsrange.length>characters.count ? nil : Range(start:startIndex.advancedBy(nsrange.location), end:startIndex.advancedBy(nsrange.location+nsrange.length))
    }
}

public var documentsFolder:NSURL {
    get {
        let folder = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        return NSURL(fileURLWithPath: folder)
    }
}


private var _randomConeData:NSData?

public extension NSData {
    public class func randomConeData(length:Int)->NSMutableData {
        let ret = NSMutableData(length: length*4)!
        let b = UnsafeMutablePointer<UInt32>(ret.mutableBytes)
        for i in 0..<length {
            b[i]=arc4random()%UInt32(i+1)
        }
        return ret
    }
    public class var savedRandomConeData:(UnsafePointer<UInt32>,Int) {
        get {
            if (_randomConeData == nil) {
                let url = documentsFolder.URLByAppendingPathComponent("randomCodeData")
                _randomConeData = NSData(contentsOfURL: url)
                if (_randomConeData == nil) {
                    if let url = NSBundle(forClass: Util.self).URLForResource("randomCodeData", withExtension: nil) {
                        _randomConeData = NSData(contentsOfURL: url)
                    }
                    if (_randomConeData == nil) {
                        _randomConeData = randomConeData(1<<16)
                        _randomConeData!.writeToURL(url, atomically: true)
                    }
                }
            }
            return (UnsafePointer<UInt32>(_randomConeData!.bytes),_randomConeData!.length/4)
        }
    }
}

public extension NSMutableData {
    public func randomizeOrder() {
        let (r,len) = NSData.savedRandomConeData
        let bb = UnsafeMutablePointer<UInt8>(mutableBytes)
        let ll = length
        for offs in 0.stride(to:ll, by:len) {
            let l = min(ll-offs,len)
            let b = bb+offs
            for i in 0..<l {
                let j = i + Int(r[l-(1+i)])
                //print("[\(i):\(l-(1+i))]+\(r[l-(1+i)]) = \(j) -- ")
                if (i != j) {
                    let c = b[i]
                    b[i] = b[j]
                    b[j] = c
                }
            }
        }
        //print("\n")
    }
    public func derandomizeOrder() {
        let (r,len) = NSData.savedRandomConeData
        let bb = UnsafeMutablePointer<UInt8>(mutableBytes)
        let ll = length
        for offs in 0.stride(to:ll, by:len) {
            let l = min(ll-offs,len)
            let b = bb+offs
            for i in (l-1).stride(through: 0, by: -1) {
                let j = i + Int(r[l-(1+i)])
                //print("[\(i):\(l-(1+i))]+\(r[l-(1+i)]) = \(j) -- ")
                if (i != j) {
                    let c = b[i]
                    b[i] = b[j]
                    b[j] = c
                }
            }
        }
        //print("\n")
    }
}


public extension NSData {
    public var withRandomizedOrder:NSMutableData {
        get {
            let ret = mutableCopy() as! NSMutableData
            ret.randomizeOrder()
            return ret
        }
    }
    public var withDerandomizedOrder:NSMutableData {
        get {
            let ret = mutableCopy() as! NSMutableData
            ret.derandomizeOrder()
            return ret
        }
    }
}


private let pathAllowedChars = NSCharacterSet(charactersInString: "<>|\\:/()&;\t?*~").invertedSet

public extension String {
    public var escapeForPathComponent:String {
        get {
            return String(characters.map({ (c:Character) -> String in
                pathAllowedChars.characterIsMember(String(c).utf16.first!) ? String(c) : "_"
            }))
        }
    }
}

        