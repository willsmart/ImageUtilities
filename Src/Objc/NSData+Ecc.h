typedef enum{
    ECC_tinyViterbi=1,
    ECC_rs,
    ECC_viterbi37
} EccType;

@interface NSData(ECCCode)
+(void)setEccType:(int)v;
+(int)eccType;
+(void)setDoubleEncode:(bool)v;
+(bool)doubleEncode;

@property (nonatomic,strong,readonly) NSMutableData * __nonnull toBits, * __nonnull fromBits, *__nonnull shiftedLeft;
@property (nonatomic,strong,readonly) NSMutableString *__nonnull descriptionsShiftedThroughBits;
@property (nonatomic,strong,readonly) NSMutableData * __nonnull eccBitsEncoded;
@property (nonatomic,strong,readonly) NSMutableData * __nullable eccBitsDecoded;
@property (nonatomic,strong,readonly) NSMutableData * __nonnull eccEncoded;
@property (nonatomic,strong,readonly) NSMutableData * __nullable eccDecoded;
@end

