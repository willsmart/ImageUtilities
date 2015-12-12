
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




private let pathAllowedChars = NSCharacterSet(charactersInString: "<>|\\:/()&;\t?*~").invertedSet

public extension String {
    public var escapeForPathComponent:String {
        get {
            return String(characters.map({ (c:Character) -> Character in
                pathAllowedChars.characterIsMember(String(c).utf16.first!) ? c : "_"
            }))
        }
    }
}

public extension NSURL {
    public var pathRelativeToDocumentsFolder:String? {
        get {
            let str = absoluteString
            if fileURL {
                if let r = str.rangeOfString("/Application/[\\w-]+/Documents/", options: .RegularExpressionSearch) {
                    return str.substringFromIndex(r.endIndex)
                }
                else {return nil}
            }
            else {return nil}
        }
    }
    
    public func annexFileURLInDirectory(dir:NSURL)->NSURL {
        let path:String
        if let relPath = pathRelativeToDocumentsFolder {
            path = "doc \(relPath)"
        }
        else {
            path = absoluteString
        }
        return dir.URLByAppendingPathComponent(path.escapeForPathComponent)
    }
    
    public var thumbnailURL:NSURL {
        get {
            return annexFileURLInDirectory(documentsFolder.URLByAppendingPathComponent("thumbnails", isDirectory: true))
        }
    }
}





