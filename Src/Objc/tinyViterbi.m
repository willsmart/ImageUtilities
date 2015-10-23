// Will's tiny viterbi K 7, rate 1/2 encoder/decoder.
// Inspired mainly by Phil Karn's great c code, heavily modified to be faster, more accurate, more terse.
// Copyright 2015 Will Smart

#define DEB(...) //__VA_ARGS__
#define dprint(...) DEB(printf(__VA_ARGS__);)



/* Normal function integrated from -Inf to x. Range: 0-1 */
#define	normal(x)	(0.5 + 0.5*erf((x)/M_SQRT2))

static double s_relativeNoise=0.5, s_signalAmplitude=250;
uint8_t s_poly[256], s_hasInit=0;
double s_metricA[256], s_metricB[256];
static NSMutableData *s_pathData=nil;

@implementation Viterbi

+(double)relativeNoise {return s_relativeNoise;}
+(void)setRelativeNoise:(double)v {s_relativeNoise = v; s_hasInit = NO;}
+(double)signalAmplitude {return s_signalAmplitude;}
+(void)setSignalAmplitude:(double)v {s_signalAmplitude = v; s_hasInit = NO;}
+(void)setup {
    if (!s_pathData) s_pathData = [NSMutableData data];
    if (s_hasInit) return;
    s_hasInit = YES;
    memset(s_poly,0,sizeof(s_poly));
    uint8_t polys[2] = {0x6d,0x4f}; //NASA K=7 code
    
    const double amp = 128, noise = 0.5, scale=4;
    for (int i = 0; i<256; i++) {
        for (uint8_t bit = 0;bit<8;bit++) s_poly[i]^=(1&((i&polys[0])>>bit))|((1&((i&polys[1])>>bit))<<1);
        
		double
            pOne =  (i==255?1:normal(((i-127.5)/amp - 1)/noise))
                        -(i==0?0:normal(((i-128.5)/amp - 1)/noise)),
            pZero = (i==255?1:normal(((i-127.5)/amp + 1)/noise))
                        -(i==0?0:normal(((i-128.5)/amp + 1)/noise));

		s_metricA[i] = log2(2*pZero/(pOne+pZero))*scale;
		s_metricB[i] = log2(2*pOne/(pOne+pZero))*scale;
    }
}

@end



@implementation NSData(Viterbi)

#define ENCODEDNIBBLE(___b,__state) ({const uint8_t __b=(___b); \
            const uint8_t s1 = ((__state)<<1)|((__b)&1), \
                s2=((s1)<<1)|(((__b)>>1)&1), \
                s3=((s2)<<1)|(((__b)>>2)&1); \
                __state=((s3)<<1)|(((__b)>>3)&1); \
            dprint("[%d](%d)s%d p%d -- [%d](%d)s%d p%d -- [%d](%d)s%d p%d -- [%d](%d)s%d p%d -- ",j+1,((__b)&1),s1,s_poly[s1]&1,j+2,(((__b)>>1)&1),s2,s_poly[s2]&1,j+3,(((__b)>>2)&1),s3,s_poly[s3]&1,j+4,(((__b)>>3)&1),__state,s_poly[__state]&1);j+=4; \
            s_poly[s1] \
            | (( \
                s_poly[s2] \
                | (( \
                    s_poly[s3]|(s_poly[__state]<<2) \
                  )<<2) \
              )<<2); \
        })

-(NSMutableData*)viterbiEncoded {
    [Viterbi setup];
    
    NSMutableData *ret = [NSMutableData dataWithLength:2*(self.length+1)];
    const uint8_t *from = (const uint8_t*)self.bytes;
    uint8_t *to = (uint8_t*)ret.mutableBytes;
    uint8_t state=0;
    int j=0;
    for (int i=0,N=(int)self.length;i<N;i++) {
        const uint8_t b = from[i];
        dprint(" -- %02x -- ",b);
        *(to++)=ENCODEDNIBBLE(b, state);
        *(to++)=ENCODEDNIBBLE(b>>4, state);
    }
    *(to++)=ENCODEDNIBBLE(0, state);
    *(to++)=ENCODEDNIBBLE(0, state);

    printf("for\n%s\n%s\n",self.description.UTF8String,ret.description.UTF8String);

    return ret;
}
    


-(NSMutableData*)viterbiBitsDecoded {
    if (!self.length) return NSMutableData.data;
    
    [Viterbi setup];
    
    objc_sync_enter(s_pathData);
    if (s_pathData.length < (self.length/2+64)*8) {
        s_pathData.length = (self.length/2+64)*8;
    }
    uint64_t *paths=(uint64_t*)s_pathData.mutableBytes;
    
    int retN=(int)self.length/16-1;
    
    const uint8_t *from=(const uint8_t*)self.bytes;
    
    double states[64]={0}, tmpStates[64], *endStates;
    for (int i=63; i>0; i--) states[i] = -999999;
    

#define BUTTERFLYindexes \
    (0,aa),  (6,aa),  (8,aa),  (14,aa), \
    (2,bb),  (4,bb), (10,bb),  (12,bb), \
    (1,ab),  (7,ab),  (9,ab),  (15,ab), \
    (3,ba),  (5,ba), (11,ba),  (13,ba), \
    \
   (19,aa), (21,aa), (27,aa),  (29,aa), \
   (17,bb), (23,bb), (25,bb),  (31,bb), \
   (18,ab), (20,ab), (26,ab),  (28,ab), \
   (16,ba), (22,ba), (24,ba),  (30,ba)

#define MAC(...) __VA_ARGS__
#define EACH32(...) _EACH32(__VA_ARGS__)
#define _EACH32(__m,__00,__01,__02,__03,__04,__05,__06,__07,__10,__11,__12,__13,__14,__15,__16,__17,__20,__21,__22,__23,__24,__25,__26,__27,__30,__31,__32,__33,__34,__35,__36,__37) MAC(__m __00) MAC(__m __01) MAC(__m __02) MAC(__m __03) MAC(__m __04) MAC(__m __05) MAC(__m __06) MAC(__m __07) MAC(__m __10) MAC(__m __11) MAC(__m __12) MAC(__m __13) MAC(__m __14) MAC(__m __15) MAC(__m __16) MAC(__m __17) MAC(__m __20) MAC(__m __21) MAC(__m __22) MAC(__m __23) MAC(__m __24) MAC(__m __25) MAC(__m __26) MAC(__m __27) MAC(__m __30) MAC(__m __31) MAC(__m __32) MAC(__m __33) MAC(__m __34) MAC(__m __35) MAC(__m __36) MAC(__m __37)

#define NOTaa bb
#define NOTab ba
#define NOTba ab
#define NOTbb aa
#define NOTstates tmpStates
#define NOTtmpStates states

#define BUTTERFLIES(__states) { \
                dprint("\n%.0f,%.0f\n",from[0]/25.6,from[1]/25.6) \
                const double \
                    aa = s_metricA[from[0]]+s_metricA[from[1]], \
                    ab = s_metricA[from[0]]+s_metricB[from[1]], \
                    ba = s_metricB[from[0]]+s_metricA[from[1]], \
                    bb = s_metricB[from[0]]+s_metricB[from[1]]; \
                const double *fromState = __states; \
                double *toState = NOT##__states; \
                \
                *paths=0; \
                EACH32(MYBUTTERFLY,BUTTERFLYindexes) \
                PRINTBUTTERFLIES(toState) \
                dprint("%016qx\n",*paths) \
                paths++; \
                from+=2; \
                if (!--togo) {endStates = toState;break;} \
            }
    

#define MYBUTTERFLY(__i,__aa) _MYBUTTERFLY(__i,__aa,NOT##__aa)
#define	_MYBUTTERFLY(__i, __left, __right) { \
	const double metLeft = fromState[__i], metRight = fromState[__i+32], metDif = metRight-metLeft, __dif=__right-__left; \
    dprint("%.0f %.0f %.0f %.0f  ",__left,__right,metLeft,metRight) \
    dprint("[%d]%.0f:%d->%.0f  ",__i<<1,metDif+__dif,metDif+__dif>0,(metDif+__dif>0 ? metRight+__right : metLeft+__left)) \
    (*paths)|=((uint64_t)((metDif+__dif>0)|((metDif>__dif)<<1)))<<(__i<<1); \
	toState[__i<<1] = metDif+__dif>0 ? metRight+__right : metLeft+__left; \
    dprint("[%d]%.0f:%d->%.0f  ",(__i<<1)+1,metDif-__dif,metDif-__dif>0,(metDif-__dif>0 ?  metRight+__left : metLeft+__right)) \
	toState[(__i<<1)+1] = metDif>__dif ? metRight+__left : metLeft+__right; \
}
// sorry for obfuscation, I just enjoy playing with macros :)

#define PRINTBUTTERFLIES(__states) DEB({ \
    printf("\n" #__states "[%d]: ",bfi++); \
    for (int i=0;i<64;i++) { \
        printf("[%d]%.0f ",i,__states[i]); \
    } \
    printf("\n"); \
})
    
    int bfi=1;
    for (int togo = retN*8+6; togo>=0;) {
        for (int biti = 0; biti<8; biti+=2) {
            BUTTERFLIES(states)
            BUTTERFLIES(tmpStates)
        }
    }
    
    NSMutableData *ret = [NSMutableData dataWithLength:retN];
    uint8_t *to=(uint8_t*)ret.mutableBytes, state=0;
    uint8_t byte=0;
    for (uint8_t bit = 0x80;bit;bit>>=1) {
        dprint("%0qx ",paths[-1])
        if (*(--paths)&(1L<<state)) {
            state=(state>>1)|0x20;
            byte|=bit;
        }
        else state>>=1;
        dprint("\ns%d(%02x) ",state,byte)
    }
    
    for (int bytei=retN-1;bytei>=0;bytei--) {
        for (uint8_t bit = 0x80;bit;bit>>=1) {
            dprint("%016qx ",paths[-1])
            if (*(--paths)&(1L<<state)) {
                state=(state>>1)|0x20;
                to[bytei]|=bit;
            }
            else state>>=1;
            dprint("\ns%d(%02x) ",state,to[bytei])
        }
    }
    
    printf("for\n%s\n%s\n",self.fromBits.description.UTF8String,ret.description.UTF8String);
    
    objc_sync_exit(s_pathData);
    return ret;
}

@end

