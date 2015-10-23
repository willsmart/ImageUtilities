
@interface NSData(ECCCode)
@property (nonatomic,strong,readonly) NSMutableData * __nonnull toBits, * __nonnull fromBits;
@property (nonatomic,strong,readonly) NSMutableData * __nonnull eccBitsEncoded;
@property (nonatomic,strong,readonly) NSMutableData * __nullable eccBitsDecoded;
@property (nonatomic,strong,readonly) NSMutableData * __nonnull eccEncoded;
@property (nonatomic,strong,readonly) NSMutableData * __nullable eccDecoded;
@end

