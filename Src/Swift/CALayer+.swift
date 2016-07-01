public extension CALayer {
    // this allows you to set border colors from the storyboard
    public var borderUIColor:UIColor? {
        get {return(borderColor == nil ? nil : UIColor(CGColor:borderColor!))}
        set {borderColor = newValue?.CGColor}
    }
    
    
    // this allows you to set background colors from the storyboard
    public var backgroundUIColor:UIColor? {
        get {return(backgroundColor == nil ? nil : UIColor(CGColor:backgroundColor!))}
        set {backgroundColor = newValue?.CGColor}
    }
}