
@interface NSData(ReedSolomon)
@property (nonatomic,strong,readonly) NSMutableData * __nonnull reedSolomonEncoded;
@property (nonatomic,strong,readonly) NSMutableData * __nullable reedSolomonDecoded;
@end

