@implementation NSData(ECCCode)

static bool s_doubleEncode=true;
+(void)setDoubleEncode:(bool)v {s_doubleEncode = v;}
+(bool)doubleEncode {return s_doubleEncode;}

static int s_eccType = ECC_tinyViterbi;
+(void)setEccType:(int)v {s_eccType = v;}
+(int)eccType {return s_eccType;}

-(NSMutableData*)eccBitsEncoded {
    switch (s_eccType) {
        default:return self.eccEncoded.toBits;
    }
}
-(NSMutableData*)eccEncoded {
    NSMutableData *ret;
    switch (s_eccType) {
        case ECC_tinyViterbi:default: ret=(s_doubleEncode?self.viterbiEncoded:self).viterbiEncoded;break;
        case ECC_viterbi37: ret=(s_doubleEncode?self.oviterbiEncoded:self).oviterbiEncoded;break;
        case ECC_rs: ret=(s_doubleEncode?self.reedSolomonEncoded:self).reedSolomonEncoded;break;
    }
    //printf("encoded\n%s\nto\n%s\n", self.description.UTF8String, ret.description.UTF8String);
    return ret;
}

-(NSMutableData*)eccBitsDecoded {
    NSMutableData *ret;
    switch (s_eccType) {
        case ECC_tinyViterbi:default:
            //[(s_doubleEncode?self.oviterbiBitsDecoded.toBits:self) oviterbiBitsDecoded];
            ret=(s_doubleEncode?self.viterbiBitsDecoded.toBits:self).viterbiBitsDecoded;break;
        case ECC_viterbi37: ret=(s_doubleEncode?self.oviterbiBitsDecoded.toBits:self).oviterbiBitsDecoded;break;
        case ECC_rs: return self.eccDecoded;
    }
    //printf("decoded (bits then bytes)\n%s\n%s\nto\n%s\n", self.description.UTF8String, self.fromBits.description.UTF8String, ret.description.UTF8String);
    return ret;
}
-(NSMutableData*)eccDecoded {
    NSMutableData *ret;
    switch (s_eccType) {
        case ECC_rs: ret=(s_doubleEncode?self.reedSolomonDecoded:self).reedSolomonDecoded;break;
        default: return self.toBits.eccBitsDecoded;
    }
    //printf("decoded\n%s\nto\n%s\n", self.description.UTF8String, ret.description.UTF8String);
    return ret;
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

