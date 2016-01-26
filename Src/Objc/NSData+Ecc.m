#import "NSData+MD5.h"

@implementation NSData(ECCCode)

static int s_encodeCount=3;
+(void)setEncodeCount:(int)v {s_encodeCount = v;}
+(int)encodeCount {return s_encodeCount;}

static int s_eccType = ECC_tinyViterbi;
+(void)setEccType:(EccType)v {s_eccType = v;}
+(EccType)eccType {return s_eccType;}

#define DEB(...) //__VA_ARGS__
#define dprint(...) DEB(printf(__VA_ARGS__);)

-(NSMutableData*)eccEncoded {
    NSMutableData *ret=nil;
    for (int i=s_encodeCount;i>0;i--) {
        switch (s_eccType) {
            case ECC_tinyViterbi:default: ret=(ret?ret:self).viterbiEncoded;break;
        }
    }
    dprint("encoded\n%s\nto\n%s\n", self.description.UTF8String, ret.description.UTF8String)
    DEB(
    if (![ret.eccDecoded isEqualToData:self]) {
        dprint("encoded+decode failed\n")
    })
    return ret;
}

-(NSMutableData*)eccBitsDecoded {
    NSMutableData *ret=nil;
    for (int i=s_encodeCount;i>0;i--) {
        switch (s_eccType) {
            case ECC_tinyViterbi:default:ret=(ret?ret:self).viterbiBitsDecoded;break;
        }
        if (i>1) ret=ret.toBits;
    }
    dprint("decoded (bits then bytes)\n%s\n%s\nto\n%s\n", self.description.UTF8String, self.fromBits.description.UTF8String, ret.description.UTF8String)
    return ret;
}

-(NSMutableData*)eccDecoded {
    return self.toBits.eccBitsDecoded;
}



static uint32_t s_expectedId=0x683fe635;

static int s_enc32Len=0;
static int enc32Len() {
    if (!s_enc32Len) s_enc32Len = (int)[NSData dataWithBytes:&s_expectedId length:4].eccEncoded.length;
    return s_enc32Len;
}

#define BITFROMPIX(__count,__pixelModulus,rgbw) MIN(0xff,ABS(ABS(((int32_t)((__count).rgbw%((__count).pixelCount*(__pixelModulus).rgbw)))*0x200/(int32_t)((__count).pixelCount*(__pixelModulus).rgbw)-0x180)-0x100))


-(NSMutableData*)subdataBitsFromPixelCountsWithRange:(NSRange)range pixelModulus:(EccPixelModulus)pixelModulus {
    return [self subdataBitsFromPixelCountsWithRange:range length:(NSInteger)round(range.length) pixelModulus:pixelModulus];
}

-(NSMutableData*)subdataBitsFromPixelCountsFromLocation:(NSInteger)from length:(NSInteger)retLen pixelModulus:(EccPixelModulus)pixelModulus {
    return [self subdataBitsFromPixelCountsWithRange:NSMakeRange(from,10000000) length:retLen pixelModulus:pixelModulus];
}

-(NSMutableData*)subdataBitsFromPixelCountsWithRange:(NSRange)range length:(NSInteger)retLen pixelModulus:(EccPixelModulus)pixelModulus {
    int biti=0;
    const int modLen = PIXMODLEN(pixelModulus);
    NSInteger Npix=self.length/sizeof(EccPixelCount), offs = MIN(Npix*modLen,(NSInteger)round(range.location)), len = MIN(Npix*modLen-offs,(NSInteger)round(range.length));

    if ((retLen<=0)||(len<=0)||!modLen) return NSMutableData.data;

    NSMutableData *ret = [NSMutableData dataWithLength:retLen];
    int8_t *bits = (int8_t*)ret.mutableBytes;

    const EccPixelCount *counts = ((const EccPixelCount *)self.bytes);
    
    if (retLen>=len) {
        EccPixelCount count = *(counts+=offs/modLen);
        if (offs%modLen) {
            int mi = offs%modLen;
            if (pixelModulus.g&&((--mi)<=0)) {bits[biti++]=BITFROMPIX(count,pixelModulus,g);if (biti>=len) return ret;}
            if (pixelModulus.b&&((--mi)<=0)) {bits[biti++]=BITFROMPIX(count,pixelModulus,b);if (biti>=len) return ret;}
            if (pixelModulus.w&&((--mi)<=0)) {bits[biti++]=BITFROMPIX(count,pixelModulus,w);if (biti>=len) return ret;}
            count = *++counts;
        }
        while(YES) {
            if (pixelModulus.r) {bits[biti++]=BITFROMPIX(count,pixelModulus,r);if (biti>=len) return ret;}
            if (pixelModulus.g) {bits[biti++]=BITFROMPIX(count,pixelModulus,g);if (biti>=len) return ret;}
            if (pixelModulus.b) {bits[biti++]=BITFROMPIX(count,pixelModulus,b);if (biti>=len) return ret;}
            if (pixelModulus.w) {bits[biti++]=BITFROMPIX(count,pixelModulus,w);if (biti>=len) return ret;}
            count = *++counts;
        }
    }
    else {
        for (;biti<retLen;biti++) {
            EccPixelCount count = counts[(offs+biti)/modLen];
            NSInteger N = (len-1-biti)/retLen+1;
            if (N==1) {
                switch (PIXMODINDEXTOCOL((offs+biti)%modLen,pixelModulus)) {
                    case 0:bits[biti] = BITFROMPIX(count,pixelModulus,r);break;
                    case 1:bits[biti] = BITFROMPIX(count,pixelModulus,g);break;
                    case 2:bits[biti] = BITFROMPIX(count,pixelModulus,b);break;
                    case 3:bits[biti] = BITFROMPIX(count,pixelModulus,w);break;
                }
            }
            else {
                uint16_t sum;
                switch (PIXMODINDEXTOCOL((offs+biti)%modLen,pixelModulus)) {
                    case 0:sum = BITFROMPIX(count,pixelModulus,r);break;
                    case 1:sum = BITFROMPIX(count,pixelModulus,g);break;
                    case 2:sum = BITFROMPIX(count,pixelModulus,b);break;
                    case 3:sum = BITFROMPIX(count,pixelModulus,w);break;
                }
                for (int j=(int)(retLen*(N-1));j;j-=retLen) {
                    int cj = (int)(offs+biti+j);
                    EccPixelCount count2 = counts[cj/modLen];
                    switch (PIXMODINDEXTOCOL(cj%modLen,pixelModulus)) {
                        case 0:sum += BITFROMPIX(count2,pixelModulus,r);break;
                        case 1:sum += BITFROMPIX(count2,pixelModulus,g);break;
                        case 2:sum += BITFROMPIX(count2,pixelModulus,b);break;
                        case 3:sum += BITFROMPIX(count2,pixelModulus,w);break;
                    }
                }
                bits[biti]=(uint16_t)(sum/N);
            }
        }
        return ret;
    }
}

-(NSData*)eccPixelCountsDecoded:(bool)xIsMajor pixelModulusOptions:(NSArray*)pixelModulusOptions {
    NSInteger Npix=self.length/sizeof(EccPixelCount);
    const int idLen=enc32Len(), idLen8=idLen*8;
    if (self.length<idLen8*2) return nil;

    int power = (int)round(log2(Npix));
    int minorWidth = 1<<(power/2);
    int majorWidth = 1<<((power+1)/2);
    int width = (xIsMajor?majorWidth:minorWidth);
    
    NSData *me = self;
    NSMutableData *d, *mme=nil;
    
    while(YES) {
        NSMutableData *rme = me.mutableCopy;
        [rme derandomizeOrderWithStride:sizeof(EccPixelCount)];
        
        for (NSNumber *o in pixelModulusOptions) {
            EccPixelModulus pixelModulus = PIXMODFROMOBJECT(o);
            
            int modLen = PIXMODLEN(pixelModulus);
            NSInteger Nbits = Npix*modLen;
            if (Nbits>=idLen8*2
                &&((d = [rme subdataBitsFromPixelCountsWithRange:NSMakeRange(0, idLen8) pixelModulus:pixelModulus].eccBitsDecoded))
                &&(*(const uint32_t*)d.bytes == s_expectedId)
                &&((d = [rme subdataBitsFromPixelCountsWithRange:NSMakeRange(idLen8, idLen8) pixelModulus:pixelModulus].eccBitsDecoded))
            ) {
                const uint32_t len = (*(const uint32_t*)d.bytes)*8;
                if (len+idLen8*2<=rme.length) {
                    d = [rme subdataBitsFromPixelCountsFromLocation:idLen8*2 length:len pixelModulus:pixelModulus];
                    return d.eccBitsDecoded.gzipInflate;
                }
            }
        }
        
        if (me.length/2<idLen8*2) return nil;
        
        if (!mme) {
            mme = me.mutableCopy;
            me = mme;
        }
        
        EccPixelCount *pixs=(EccPixelCount*)mme.mutableBytes;
        if (xIsMajor) {
            for (NSInteger N=mme.length/2/sizeof(EccPixelCount),i=0;i<N;i++) {
                const EccPixelCount a = pixs[i<<1], b = pixs[(i<<1)+1];
                pixs[i]=(EccPixelCount){
                    a.pixelCount+b.pixelCount,
                    a.r+b.r,
                    a.g+b.g,
                    a.b+b.b,
                    a.w+b.w
                };
            }
            width>>=1;
        }
        else {
            for (NSInteger N=mme.length/2/sizeof(EccPixelCount),i=0,j=0;i<N;i++,j+=((j+1)%width?1:1+width)) {
                const EccPixelCount a = pixs[j], b = pixs[j+width];
                pixs[i]=(EccPixelCount){
                    a.pixelCount+b.pixelCount,
                    a.r+b.r,
                    a.g+b.g,
                    a.b+b.b,
                    a.w+b.w
                };
            }
        }
        xIsMajor = !xIsMajor;
        mme.length = mme.length/2;
    }
}
    

-(NSMutableData*)eccGridEncoded:(EccPixelModulus)pixelModulus {
    const int modLen = PIXMODLEN(pixelModulus);
    if (!modLen) return NSMutableData.data;
    const int idLen=enc32Len();
    NSMutableData *payload = self.tightGzipDeflate.eccEncoded;
    if (!payload) payload = NSMutableData.data;
    int _Nbits = (int)(payload.length+idLen*2)*8;
    int Npix = (int)round(pow(2,ceil(log2((_Nbits+modLen-1)/modLen))));
    int Nbits = Npix*modLen;
    NSMutableData *d = [NSMutableData dataWithLength:Nbits/8];
    uint8_t *bytes=(uint8_t*)d.mutableBytes;
    const uint8_t *payloadBytes=(const uint8_t*)payload.mutableBytes;

    uint32_t v = s_expectedId;
    NSMutableData *idd = [NSData dataWithBytes:&v length:4].eccEncoded;
    memcpy(bytes,idd.bytes,idLen);

    v = (uint32_t)payload.length;
    idd = [NSData dataWithBytes:&v length:4].eccEncoded;
    memcpy(bytes+idLen,idd.bytes,idLen);

    for (int offs=idLen*2;offs<Nbits/8;offs+=payload.length) {
        memcpy(bytes+offs,payloadBytes,MIN(payload.length,Nbits/8-offs));
    }
    d = d.toBits;
    [d randomizeOrderWithStride:modLen];// todo randomize bits in one call
    d=d.fromBits;
    return d;
}
    


-(NSMutableData*)toBits {
    NSMutableData *bitsd = [NSMutableData dataWithLength:self.length*8];
    uint8_t *bits=(uint8_t*)bitsd.mutableBytes;
    const uint8_t *me=(const uint8_t*)self.bytes;
    uint8_t b;
    int j;
    for (int i=(int)self.length-1;i>=0;i--) {
        for (j=0,b=1;b;j++,b<<=1) {
            bits[(i<<3)+j]=(me[i]&b?254:1);
        }
    }
    return bitsd;
}
    
-(NSMutableData*)fromBits {
    NSMutableData *ret = [NSMutableData dataWithLength:(self.length+7)/8];
    uint8_t *bits=(uint8_t*)ret.mutableBytes;
    const uint8_t *me=(const uint8_t*)self.bytes;
    for (int i=(int)self.length-1;i>=0;i--) {
        if (me[i]>=0x80) bits[i/8]|=(1<<(i&7));
    }
    return ret;
}

-(NSMutableData*)shiftedLeft {
    if (!self.length) return NSMutableData.data;
    const uint8_t *from = (const uint8_t*)self.bytes;NSInteger fromN = self.length, toN = fromN + ((from[fromN-1]&0x80) != 0);
    NSMutableData *ret = [NSMutableData dataWithLength:fromN];
    uint8_t *to = (uint8_t*)ret.mutableBytes;
    uint8_t c=0;
    int i=0;
    for (;i<fromN; i++) {
        to[i]=(from[i]<<1)|c;
        c = from[i]>>7;
    }
    if (i<toN) to[i]=c;
    return ret;
}

-(NSString*)descriptionsShiftedThroughBits {
    NSMutableString *ret = self.description.mutableCopy;
    NSData *d = self;
    for (int i=1;i<4;i++) {
        d = d.shiftedLeft;
        [ret appendFormat:@"\n%@",d.description];
    }
    return ret;
}
    
@end










@implementation NSMutableData(RandomizeOrder)



-(void)randomizeOrder {
    const uint32_t *r = NSData.randomConeData;
    NSInteger len = NSData.randomConeDataLength, ll = self.length;
    uint8_t *b = (uint8_t*)self.mutableBytes, tmp;
    NSInteger offs = 0,j;
    while (ll-offs>=len) {
        for (NSInteger i=0; i<len; i++,b++) {
            if ((j = r[len-1-i])) {
                tmp = *b; *b = b[j]; b[j]=tmp;
            }
        }
        offs+=len;
    }
    for (NSInteger i=0, N=ll-offs; i<N; i++,b++) {
        if ((j = r[N-1-i])) {
            tmp = *b; *b = b[j]; b[j]=tmp;
        }
    }
}
-(void)randomizeOrderWithStride:(NSInteger)stride {
    const uint32_t *r = NSData.randomConeData;
    NSInteger len = NSData.randomConeDataLength, ll = self.length/stride;
    switch (stride) {
        case 1:[self randomizeOrder];break;
        case 2:{
            uint16_t *b = (uint16_t*)self.mutableBytes, tmp;
            NSInteger offs = 0,j;
            while (ll-offs>=len) {
                for (NSInteger i=0; i<len; i++,b++) {
                    if ((j = r[len-1-i])) {
                        tmp = *b; *b = b[j]; b[j]=tmp;
                    }
                }
                offs+=len;
            }
            for (NSInteger i=0, N=ll-offs; i<N; i++,b++) {
                if ((j = r[N-1-i])) {
                    tmp = *b; *b = b[j]; b[j]=tmp;
                }
            }
        }break;
        case 4:{
            uint32_t *b = (uint32_t*)self.mutableBytes, tmp;
            NSInteger offs = 0,j;
            while (ll-offs>=len) {
                for (NSInteger i=0; i<len; i++,b++) {
                    if ((j = r[len-1-i])) {
                        tmp = *b; *b = b[j]; b[j]=tmp;
                    }
                }
                offs+=len;
            }
            for (NSInteger i=0, N=ll-offs; i<N; i++,b++) {
                if ((j = r[N-1-i])) {
                    tmp = *b; *b = b[j]; b[j]=tmp;
                }
            }
        }break;
        case 8:{
            uint64_t *b = (uint64_t*)self.mutableBytes, tmp;
            NSInteger offs = 0,j;
            while (ll-offs>=len) {
                for (NSInteger i=0; i<len; i++,b++) {
                    if ((j = r[len-1-i])) {
                        tmp = *b; *b = b[j]; b[j]=tmp;
                    }
                }
                offs+=len;
            }
            for (NSInteger i=0, N=ll-offs; i<N; i++,b++) {
                if ((j = r[N-1-i])) {
                    tmp = *b; *b = b[j]; b[j]=tmp;
                }
            }
        }break;
        default:{
            if (stride>512) {
                printf("Stride is too big for current impl\n");break;
            }
            uint8_t *b = (uint8_t*)self.mutableBytes, tmp[512];
            NSInteger offs = 0,j;
            while (ll-offs>=len) {
                for (NSInteger i=0; i<len; i++,b+=stride) {
                    if ((j = r[len-1-i])) {
                        memcpy(tmp,b,stride);
                        memcpy(b,b+j*stride,stride);
                        memcpy(b+j*stride,tmp,stride);
                    }
                }
                offs+=len;
            }
            for (NSInteger i=0, N=ll-offs; i<N; i++,b+=stride) {
                if ((j = r[N-1-i])) {
                    memcpy(tmp,b,stride);
                    memcpy(b,b+j*stride,stride);
                    memcpy(b+j*stride,tmp,stride);
                }
            }
        }break;
    }
}
-(void)derandomizeOrder {
    const uint32_t *r = NSData.randomConeData;
    NSInteger len = NSData.randomConeDataLength, ll = self.length;
    uint8_t *b = (uint8_t*)self.mutableBytes, tmp;
    NSInteger offs = 0,j;
    while (ll-offs>=len) {
        b+=len;
        for (NSInteger i=len-1; i>=0; i--) {
            b--;
            if ((j = r[len-1-i])) {
                tmp = *b; *b = b[j]; b[j]=tmp;
            }
        }
        b+=len;
        offs+=len;
    }
    b+=ll-offs;
    for (NSInteger N=ll-offs, i=N-1; i>=0; i--) {
        b--;
        if ((j = r[N-1-i])) {
            tmp = *b; *b = b[j]; b[j]=tmp;
        }
    }
}

-(void)derandomizeOrderWithStride:(NSInteger)stride {
    const uint32_t *r = NSData.randomConeData;
    NSInteger len = NSData.randomConeDataLength, ll = self.length/stride;
    switch (stride) {
        case 1:[self derandomizeOrder];break;
        case 2:{
            uint16_t *b = (uint16_t*)self.mutableBytes, tmp;
            NSInteger offs = 0,j;
            while (ll-offs>=len) {
                b+=len;
                for (NSInteger i=len-1; i>=0; i--) {
                    b--;
                    if ((j = r[len-1-i])) {
                        tmp = *b; *b = b[j]; b[j]=tmp;
                    }
                }
                b+=len;
                offs+=len;
            }
            b+=ll-offs;
            for (NSInteger N=ll-offs, i=N-1; i>=0; i--) {
                b--;
                if ((j = r[N-1-i])) {
                    tmp = *b; *b = b[j]; b[j]=tmp;
                }
            }
        }break;
        case 4:{
            uint32_t *b = (uint32_t*)self.mutableBytes, tmp;
            NSInteger offs = 0,j;
            while (ll-offs>=len) {
                b+=len;
                for (NSInteger i=len-1; i>=0; i--) {
                    b--;
                    if ((j = r[len-1-i])) {
                        tmp = *b; *b = b[j]; b[j]=tmp;
                    }
                }
                b+=len;
                offs+=len;
            }
            b+=ll-offs;
            for (NSInteger N=ll-offs, i=N-1; i>=0; i--) {
                b--;
                if ((j = r[N-1-i])) {
                    tmp = *b; *b = b[j]; b[j]=tmp;
                }
            }
        }break;
        case 8:{
            uint64_t *b = (uint64_t*)self.mutableBytes, tmp;
            NSInteger offs = 0,j;
            while (ll-offs>=len) {
                b+=len;
                for (NSInteger i=len-1; i>=0; i--) {
                    b--;
                    if ((j = r[len-1-i])) {
                        tmp = *b; *b = b[j]; b[j]=tmp;
                    }
                }
                b+=len;
                offs+=len;
            }
            b+=ll-offs;
            for (NSInteger N=ll-offs, i=N-1; i>=0; i--) {
                b--;
                if ((j = r[N-1-i])) {
                    tmp = *b; *b = b[j]; b[j]=tmp;
                }
            }
        }break;
        default:{
            if (stride>512) {
                printf("Stride is too big for current impl\n");break;
            }
            uint8_t *b = (uint8_t*)self.mutableBytes, tmp[512];
            NSInteger offs = 0,j;
            while (ll-offs>=len) {
                b+=len*stride;
                for (NSInteger i=len-1; i>=0; i--) {
                    b-=stride;
                    if ((j = r[len-1-i])) {
                        memcpy(tmp,b,stride);
                        memcpy(b,b+j*stride,stride);
                        memcpy(b+j*stride,tmp,stride);
                    }
                }
                b+=len*stride;
                offs+=len;
            }
            b+=(ll-offs)*stride;
            for (NSInteger N=ll-offs, i=N-1; i>=0; i--) {
                b-=stride;
                if ((j = r[N-1-i])) {
                    memcpy(tmp,b,stride);
                    memcpy(b,b+j*stride,stride);
                    memcpy(b+j*stride,tmp,stride);
                }
            }
        }break;
    }
}
@end


@implementation NSData(RandomizeOrder)
+(NSMutableData*)_randomConeData:(NSInteger)length {
    NSMutableData *ret = [NSMutableData dataWithLength:length*4];
    uint32_t *b = (uint32_t*)ret.mutableBytes;
    for (int i=0;i<length;i++) {
        b[i]=arc4random()%(i+1);
    }
    return ret;
}
static NSInteger s_randomConeDataLen=0;
+(NSInteger)randomConeDataLength {
    [self randomConeData];
    return s_randomConeDataLen;
}
static const char *s_expectedConeHash="2260ed73ca2e3a1059016b8dcf391d96";

+(const uint32_t*)randomConeData {
    static NSData *s_randomConeData=nil;
    if (!s_randomConeData) {
        NSURL *url = [NSBundle.mainBundle URLForResource:@"randomCodeData" withExtension:nil];
        if (url) s_randomConeData = [NSData dataWithContentsOfURL: url];
        if (s_randomConeData) {
            NSString *hash=s_randomConeData.md5hash,*expHash=[NSString stringWithFormat:@"%s",s_expectedConeHash];
            if (![hash isEqualToString:expHash]) {
                //printf("\nERROR: cone data invalid\n");
                //printf("\"%s\" vs \"%s\"\n",expHash.UTF8String,hash.UTF8String);
                s_randomConeData=nil;
            }
        }
        if (!s_randomConeData) {
            printf("\nERROR needed to prepare my own random cone data, this will break coding for shared images.\n");
            s_randomConeData = [self _randomConeData:1<<16];
        }
        s_randomConeDataLen = s_randomConeData.length/4;
    }
    
    return (const uint32_t*)s_randomConeData.bytes;
}





-(NSMutableData*__nonnull)withRandomizedOrder {
    NSMutableData *ret = self.mutableCopy;
    [ret randomizeOrder];
    return ret;
}
-(NSMutableData*__nonnull)withDerandomizedOrder {
    NSMutableData *ret = self.mutableCopy;
    [ret derandomizeOrder];
    return ret;
}
@end

