typedef enum{
    ECC_tinyViterbi=1,
} EccType;

typedef struct {
    uint32_t pixelCount;
    uint32_t r,g,b,w;
} EccPixelCount;

typedef struct {
    uint8_t r,g,b,w;
} EccPixelModulus;
#define PIXMODLEN(__pixelModulus) ((__pixelModulus.r!=0)+(__pixelModulus.b!=0)+(__pixelModulus.b!=0)+(__pixelModulus.w!=0))
#define PIXMODFROMOBJECT(___o) ({NSNumber *__o = (NSNumber*)(___o); \
            EccPixelModulus pixelModulus = {0,0,0,0}; \
            if ([__o isKindOfClass:NSNumber.class]) pixelModulus.w = __o.unsignedCharValue; \
            else if ([__o isKindOfClass:NSArray.class]&&((NSArray*)__o).count>=3) { \
                NSArray *a = (NSArray*)__o; \
                if ([a[0] isKindOfClass:NSNumber.class]) pixelModulus.r = [a[0] unsignedCharValue]; \
                if ([a[1] isKindOfClass:NSNumber.class]) pixelModulus.g = [a[1] unsignedCharValue]; \
                if ([a[2] isKindOfClass:NSNumber.class]) pixelModulus.b = [a[2] unsignedCharValue]; \
                if (a.count>=4 && [a[3] isKindOfClass:NSNumber.class]) pixelModulus.w = [a[3] unsignedCharValue]; \
            } \
            pixelModulus; \
    })
#define PIXMODINDEXTOCOL(___index,__pixelModulus) ({int __index=(___index); \
                switch (__index) { \
                    case 0:if (!(__pixelModulus).r) __index = ((__pixelModulus).g?1:(__pixelModulus).b?2:3);break; \
                    case 1:__index = ((__pixelModulus).r? \
                        ((__pixelModulus).g?1:((__pixelModulus).b?2:3)) \
                        :((__pixelModulus).g?((__pixelModulus).b?2:3):3) \
                    ); \
                    break; \
                    case 2:if (!((__pixelModulus).r&&(__pixelModulus).g&&(__pixelModulus).b)) __index=3;break; \
                } \
                __index; \
            })

@interface NSData(ECCCode)
+(void)setEccType:(EccType)v;
+(EccType)eccType;
+(void)setEncodeCount:(int)v;
+(int)encodeCount;

@property (nonatomic,strong,readonly) NSMutableData * __nonnull toBits, * __nonnull fromBits, *__nonnull shiftedLeft;
@property (nonatomic,strong,readonly) NSMutableString *__nonnull descriptionsShiftedThroughBits;
@property (nonatomic,strong,readonly) NSMutableData * __nullable eccBitsDecoded;
@property (nonatomic,strong,readonly) NSMutableData * __nonnull eccEncoded;
@property (nonatomic,strong,readonly) NSMutableData * __nullable eccDecoded;
-(NSMutableData*__nullable)eccPixelCountsDecoded:(bool)xIsMajor pixelModulusOptions:(NSArray*__nonnull)pixelModulusOptions;
-(NSMutableData*__nonnull)eccGridEncoded:(EccPixelModulus)pixelModulus;
@end




@interface NSMutableData(RandomizeOrder)
-(void)randomizeOrder;
-(void)randomizeOrderWithStride:(NSInteger)stride;
-(void)derandomizeOrder;
-(void)derandomizeOrderWithStride:(NSInteger)stride;
@end


@interface NSData(RandomizeOrder)
+(NSInteger)randomConeDataLength;
+(const uint32_t*__nonnull)randomConeData;
@property (readonly,nonatomic) NSMutableData *__nonnull withRandomizedOrder, *__nonnull withDerandomizedOrder;
@end

