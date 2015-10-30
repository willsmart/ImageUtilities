
@interface UIImage(DataLayer)

+(NSData*__nullable)dataLayerInImage:(NSData*__nonnull)imageData imageSize:(CGSize)imageSize;

+(bool)_addDataLayerToImageData:(NSMutableData*__nonnull)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*__nonnull)dataLayerData pixelModulusOptionIndex:(int)pixelModulusOptionIndex;

@end

