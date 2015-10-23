
typedef struct {
    uint32_t pixelCount;
    uint64_t sum;
} DataLayerPixelCount;
    
@interface UIImage(DataLayer)

+(NSData*__nullable)dataLayerInImage:(NSData*__nonnull)imageData imageSize:(CGSize)imageSize dataLayerInitialSize:(CGSize)dataLayerSize;
+(bool)addDataLayerToImageData:(NSMutableData*__nonnull)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*__nonnull)dataLayerData;



+(bool)addDataLayerToImageData:(NSMutableData*__nonnull)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*__nonnull)dataLayerData minDataLayerBytes:(int)minBytes byteModulus:(uint8_t)byteModulus;
+(bool)_addDataLayerToImageData:(NSMutableData*__nonnull)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*__nonnull)dataLayerData dataLayerSize:(CGSize)dataLayerSize byteModulus:(uint8_t)byteModulus;
+(NSMutableData*__nullable)pixelCountsForDataLayerInImage:(NSData*__nonnull)imageData imageSize:(CGSize)imageSize dataLayerSize:(CGSize)dataLayerSize byteModulus:(uint8_t)byteModulus;
+(int)idMarkDataLength;
+(NSData*__nonnull)idMarkData:(uint32_t)i;
+(int64_t)integerFromIdMarkData:(NSData*__nonnull)data;


+(NSData*__nullable)dataLayerInImage:(NSData*__nonnull)imageData imageSize:(CGSize)imageSize dataLayerInitialSize:(CGSize)dataLayerSize minDataLayerBytes:(int)minBytes byteModulus:(uint8_t)byteModulus;
+(void)copyBitsFromPixelCounts:(NSData*__nonnull)pixelCounts into:(NSMutableData*__nonnull)data byteModulus:(uint8_t)byteModulus;
+(bool)combinePixelCountsForDataLayer:(NSMutableData*__nonnull)pixelCounts size:(CGSize)dataLayerSize combinex:(bool)combinex combiney:(bool)combiney;
@end

