
typedef struct {
    uint32_t pixelCount;
    uint64_t sum;
} DataLayerPixelCount;

#define DataLayer_AnyByteModulus ((uint8_t)0xff)

@interface UIImage(DataLayer)

+(NSData*__nullable)dataLayerInImage:(NSData*__nonnull)imageData imageSize:(CGSize)imageSize byteModulus:(uint8_t)byteModulus;

+(bool)_addDataLayerToImageData:(NSMutableData*__nonnull)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*__nonnull)dataLayerData byteModulus:(uint8_t)byteModulus;

+(int)idMarkDataLength;
+(NSData*__nonnull)idMarkData:(uint32_t)i;
+(int64_t)integerFromIdMarkData:(NSData*__nonnull)data;
@end

