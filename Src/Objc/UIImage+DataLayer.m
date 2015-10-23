#import "rs.h"

uint8_t g_defaultDataLayerByteModulus[3]={10,30,50};
int g_defaultMinDataLayerBytes=2000;

@implementation UIImage(DataLayer)

static NSData *s_ref=nil;

+(NSData*)dataLayerInImage:(NSData*)imageData imageSize:(CGSize)imageSize byteModulus:(uint8_t)byteModulus {
    return [self dataLayerInImage:imageData imageSize:imageSize dataLayerInitialSize:CGSizeMake(256,256) minDataLayerBytes:2000 byteModulus:byteModulus isZipped:YES];
}



+(bool)_addDataLayerToImageData:(NSMutableData*)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*)dataLayerData byteModulus:(uint8_t)byteModulus {
    return [self _addDataLayerToImageData:imageData imageSize:imageSize dataLayerData:dataLayerData byteModulus:byteModulus dataLayerSize:CGSizeMake(0, 0) doZip:YES];
}

+(bool)_addDataLayerToImageData:(NSMutableData*)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*)dataLayerData byteModulus:(uint8_t)byteModulus dataLayerSize:(CGSize)dataLayerSize doZip:(bool)doZip {
    byteModulus = (byteModulus<sizeof(g_defaultDataLayerByteModulus)/sizeof(g_defaultDataLayerByteModulus[0]) ? g_defaultDataLayerByteModulus[byteModulus] : byteModulus);

    //printf("adding data layer [%d]:\n%s\n",(int)dataLayerData.length,dataLayerData.description.UTF8String);
    NSData *zipped = (doZip?dataLayerData.gzipDeflate:dataLayerData);
    //printf(" (zipped) [%d]:\n%s\n",(int)zipped.length,zipped.description.UTF8String);
    NSData *encoded = zipped.eccEncoded;
    //printf(" (encoded) [%d]:\n%s\n",(int)encoded.length,encoded.description.UTF8String);
    s_ref = encoded;
    NSData *idMark = [self idMarkData:(int)encoded.length];
    NSMutableData *d = idMark.mutableCopy;
    [d appendData:encoded];

    int dw=(int)round(dataLayerSize.width),dh=(int)round(dataLayerSize.height);
    if (!(dw&&dh)) {
        int power = MAX(14,(int)ceil(log2(d.length*8)));
        int xpower = (power+(imageSize.width>=imageSize.height))/2, ypower = (power+(imageSize.width<imageSize.height))/2;
        dw = 1<<xpower, dh = 1<<ypower;
/*
        NSMutableData *md = [NSMutableData dataWithLength:5];
        uint8_t *b8 = (uint8_t*)md.mutableBytes;
        uint16_t *b16 = (uint16_t*)b8;
        b8[4]=byteModulus;
        b16[0]=dw; b16[1]=dh;
        
        if (![self _addDataLayerToImageData:imageData imageSize:imageSize dataLayerData:md byteModulus:byteModulus dataLayerSize:CGSizeMake(32, 16) doZip:NO]) {
            return NO;
        }*/
    }
    else {
        printf("%d\n",(int)ceil(log2(d.length*8)));
    }
    
    //printf("adding %dx%d@%d data layer (zipped, encoded, id'd) [%d]:\n%s\n",dw,dh,byteModulus,(int)d.length,d.description.UTF8String);
    
    // filling up with random data makes for a prettier picture. Ideally these extra bytes would be used for more ecc parity
    d.length = dw*dh/8;
    uint32_t *paddingBuf = (uint32_t*)d.mutableBytes;
    for (int i = ((int)(idMark.length+encoded.length)+3)>>2, N=((int)d.length)>>2; i<N; i++) {
        paddingBuf[i]=rand();
    }
    NSMutableData *bits = d.toBits;// TODO avoid this shuffling with a bit randomizer
    [bits randomizeOrder];
    [d setData:bits.fromBits];
    
    return [self _addDataLayerToImageData:imageData imageSize:imageSize dataLayerData:d dataLayerSize:CGSizeMake(dw, dh) byteModulus:byteModulus];
}

#define dprint(...) //printf(__VA_ARGS__)
+(bool)_addDataLayerToImageData:(NSMutableData*)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*)dataLayerData dataLayerSize:(CGSize)dataLayerSize byteModulus:(uint8_t)byteModulus {
    byteModulus = (byteModulus<sizeof(g_defaultDataLayerByteModulus)/sizeof(g_defaultDataLayerByteModulus[0]) ? g_defaultDataLayerByteModulus[byteModulus] : byteModulus);

    const int dw = (int)round(dataLayerSize.width), dh = (int)round(dataLayerSize.height);
    const int imw = (int)round(imageSize.width), imh = (int)round(imageSize.height);

    if (dw<=0 || dh<=0 || imw<=0 || imh<=0) return NO;

    const uint8_t *dataBytes = (const uint8_t*)dataLayerData.bytes;
    uint8_t *imBytes = (uint8_t*)imageData.mutableBytes;

    double maxErr=0;
    int imy1 = 0, imy2 = imh/dh;
    for (int dy=0; dy<dh; dy++) {
        const int imy0 = imy1; imy1 = imy2; imy2 = (dy+2)*imh/dh;
        const int dyi = dy*dw;
        
        int imx1 = 0, imx2 = imw/dw;
        for (int dx=0; dx<dw; dx++) {
            const int imx0 = imx1; imx1 = imx2; imx2 = (dx+2)*imw/dw;
            const int di = dyi+dx;
            const bool bit = (dataBytes[di>>3]>>(di&7))&1;
            
            int32_t sum=0;
            const int32_t c=(imy1-imy0)*(imx1-imx0);
            double weightedDSum=0, roomAbove = 255, roomBelow = 255;

            for (int imy = imy0; imy<imy1; imy++) {
                const int imyi = imy*imw*4;
                const double yf = ((double)(imy+1-imy0))/(imy1-imy0);
                for (int imx = imx0; imx<imx1; imx++) {
                    const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                    
                    const int imi = imyi+imx*4;
                    const double weighting = xf*yf;
                    const uint8_t r = imBytes[imi], g = imBytes[imi+1], b = imBytes[imi+2];
                    roomAbove = fmin(roomAbove,(255-fmax(r,fmax(g,b)))/weighting);
                    roomBelow = fmin(roomBelow,fmin(r,fmin(g,b))/weighting);

                    sum += ((uint32_t)r)*2+g+b;
                    weightedDSum+=4*weighting;
                }
                if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                    const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                    
                    const int imi = imyi+imx*4;
                    const double weighting = xf*yf;
                    const uint8_t r = imBytes[imi], g = imBytes[imi+1], b = imBytes[imi+2];
                    roomAbove = fmin(roomAbove,(255-fmax(r,fmax(g,b)))/weighting);
                    roomBelow = fmin(roomBelow,fmin(r,fmin(g,b))/weighting);
                }
            }
            if (imy2<=imh) for (int imy = imy1; imy<imy2; imy++) {
                const int imyi = imy*imw*4;
                const double yf = ((double)(imy2-1-imy))/(imy2-imy1);
                for (int imx = imx0; imx<imx1; imx++) {
                    const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                    
                    const int imi = imyi+imx*4;
                    const double weighting = xf*yf;
                    const uint8_t r = imBytes[imi], g = imBytes[imi+1], b = imBytes[imi+2];
                    roomAbove = fmin(roomAbove,(255-fmax(r,fmax(g,b)))/weighting);
                    roomBelow = fmin(roomBelow,fmin(r,fmin(g,b))/weighting);
                }
                if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                    const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                    
                    const int imi = imyi+imx*4;
                    const double weighting = xf*yf;
                    const uint8_t r = imBytes[imi], g = imBytes[imi+1], b = imBytes[imi+2];
                    roomAbove = fmin(roomAbove,(255-fmax(r,fmax(g,b)))/weighting);
                    roomBelow = fmin(roomBelow,fmin(r,fmin(g,b))/weighting);
                }
            }
            
            const int32_t cdiv = c*4*byteModulus;
            int32_t tgtMod = cdiv*(bit?3:1)/4, mod = sum%cdiv;
            if (tgtMod == mod) continue;
            const int32_t tgtSumUp=sum+tgtMod-mod+(mod>tgtMod)*cdiv, difUp = tgtSumUp-sum;
            const int32_t tgtSumDown=sum+tgtMod-mod-(mod<tgtMod)*cdiv, difDown = sum-tgtSumDown;

            int32_t newSum=-1;
            double adds=0;

            if (difUp<difDown) {
                if (roomAbove>=difUp/weightedDSum) {
                    adds = difUp/weightedDSum;
                    newSum = tgtSumUp;
                }
                else if (roomBelow>=difDown/weightedDSum) {
                    adds = -difDown/weightedDSum;
                    newSum = tgtSumDown;
                }
            }
            else if (roomBelow>=difDown/weightedDSum) {
                adds = -difDown/weightedDSum;
                newSum = tgtSumDown;
            }
            else if (roomAbove>=difUp/weightedDSum) {
                adds = difUp/weightedDSum;
                newSum = tgtSumUp;
            }
            
            if (newSum>=0) {
                dprint("[%d,%d]%d %d+%.1f*%.1f = %f == %d (^%.1f v%.1f) ; %% %d = %d  ...  ",dx,dy,bit,sum,adds,weightedDSum,sum+adds*weightedDSum,newSum,roomAbove,roomBelow,cdiv,((uint32_t)(sum+adds*weightedDSum))%cdiv);
                
                for (int imy = imy0; imy<imy1; imy++) {
                    const int imyi = imy*imw*4;
                    const double yf = ((double)(imy+1-imy0))/(imy1-imy0);
                    for (int imx = imx0; imx<imx1; imx++) {
                        const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                        
                        const int imi = imyi+imx*4;
                        const double weighting = xf*yf;
                        const int16_t add = (int16_t)round(adds*weighting);
                        imBytes[imi] = MAX(0,MIN(255,imBytes[imi]+add));
                        imBytes[imi+1] = MAX(0,MIN(255,imBytes[imi+1]+add));
                        imBytes[imi+2] = MAX(0,MIN(255,imBytes[imi+2]+add));
                    }
                    if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                        const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                        
                        const int imi = imyi+imx*4;
                        const double weighting = xf*yf;
                        const int16_t add = (int16_t)round(adds*weighting);
                        imBytes[imi] = MAX(0,MIN(255,imBytes[imi]+add));
                        imBytes[imi+1] = MAX(0,MIN(255,imBytes[imi+1]+add));
                        imBytes[imi+2] = MAX(0,MIN(255,imBytes[imi+2]+add));
                    }
                }
                if (imy2<=imh) for (int imy = imy1; imy<imy2; imy++) {
                    const int imyi = imy*imw*4;
                    const double yf = ((double)(imy2-1-imy))/(imy2-imy1);
                    for (int imx = imx0; imx<imx1; imx++) {
                        const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                        
                        const int imi = imyi+imx*4;
                        const double weighting = xf*yf;
                        const int16_t add = (int16_t)round(adds*weighting);
                        imBytes[imi] = MAX(0,MIN(255,imBytes[imi]+add));
                        imBytes[imi+1] = MAX(0,MIN(255,imBytes[imi+1]+add));
                        imBytes[imi+2] = MAX(0,MIN(255,imBytes[imi+2]+add));
                    }
                    if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                        const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                        
                        const int imi = imyi+imx*4;
                        const double weighting = xf*yf;
                        const int16_t add = (int16_t)round(adds*weighting);
                        imBytes[imi] = MAX(0,MIN(255,imBytes[imi]+add));
                        imBytes[imi+1] = MAX(0,MIN(255,imBytes[imi+1]+add));
                        imBytes[imi+2] = MAX(0,MIN(255,imBytes[imi+2]+add));
                    }
                }
                
            }
            else {
                double weightedDProdUp = 0.0,weightedDProdDown = 0.0;
                for (int imy = imy0; imy<imy1; imy++) {
                    const int imyi = imy*imw*4;
                    const double yf = ((double)(imy+1-imy0))/(imy1-imy0);
                    for (int imx = imx0; imx<imx1; imx++) {
                        const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                        
                        const int imi = imyi+imx*4;
                        const double weighting = xf*yf;
                        const uint8_t r = imBytes[imi], g = imBytes[imi+1], b = imBytes[imi+2];

                        const uint32_t rgbSum=((uint32_t)r)*2+g+b;
                        weightedDProdUp+=(0x3ff-rgbSum)*weighting;
                        weightedDProdDown+=rgbSum*weighting;
                    }
                }
                const double mulsUp = weightedDProdUp?difUp/weightedDProdUp:1;
                const double mulsDown = weightedDProdDown?difDown/weightedDProdDown:1;
                
                if (mulsUp<mulsDown) {
                    newSum = tgtSumUp;
                    dprint("[%d,%d] Can't add, must mul towards 255  %d+(1-%.3f)*%.3f = %.3f == %d ; %% %d = %d  ...  ",dx,dy,sum,mulsUp,weightedDProdUp,sum+mulsUp*weightedDProdUp,newSum,cdiv,((uint32_t)(sum+mulsUp*weightedDProdUp))%cdiv);
                    
                    for (int imy = imy0; imy<imy1; imy++) {
                        const int imyi = imy*imw*4;
                        const double yf = ((double)(imy+1-imy0))/(imy1-imy0);
                        for (int imx = imx0; imx<imx1; imx++) {
                            const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                            
                            const int imi = imyi+imx*4;
                            const double weighting = xf*yf;
                            const double mul = 1-mulsUp*weighting;
                            imBytes[imi] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi])*mul))));
                            imBytes[imi+1] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+1])*mul))));
                            imBytes[imi+2] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+2])*mul))));
                        }
                        if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                            const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                            
                            const int imi = imyi+imx*4;
                            const double weighting = xf*yf;
                            const double mul = 1-mulsUp*weighting;
                            imBytes[imi] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi])*mul))));
                            imBytes[imi+1] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+1])*mul))));
                            imBytes[imi+2] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+2])*mul))));
                        }
                    }
                    if (imy2<=imh) for (int imy = imy1; imy<imy2; imy++) {
                        const int imyi = imy*imw*4;
                        const double yf = ((double)(imy2-1-imy))/(imy2-imy1);
                        for (int imx = imx0; imx<imx1; imx++) {
                            const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                            
                            const int imi = imyi+imx*4;
                            const double weighting = xf*yf;
                            const double mul = 1-mulsUp*weighting;
                            imBytes[imi] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi])*mul))));
                            imBytes[imi+1] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+1])*mul))));
                            imBytes[imi+2] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+2])*mul))));
                        }
                        if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                            const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                            
                            const int imi = imyi+imx*4;
                            const double weighting = xf*yf;
                            const double mul = 1-mulsUp*weighting;
                            imBytes[imi] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi])*mul))));
                            imBytes[imi+1] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+1])*mul))));
                            imBytes[imi+2] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+2])*mul))));
                        }
                    }
                }
                else {
                    newSum = tgtSumDown;
                    dprint("[%d,%d] Can't add, must mul towards 0  %d-(1-%.3f)*%.3f = %.3f == %d ; %% %d = %d  ...  ",dx,dy,sum,mulsDown,weightedDProdDown,sum-mulsDown*weightedDProdDown,newSum,cdiv,((uint32_t)(sum-mulsDown*weightedDProdDown))%cdiv);
                    
                    for (int imy = imy0; imy<imy1; imy++) {
                        const int imyi = imy*imw*4;
                        const double yf = ((double)(imy+1-imy0))/(imy1-imy0);
                        for (int imx = imx0; imx<imx1; imx++) {
                            const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                            
                            const int imi = imyi+imx*4;
                            const double weighting = xf*yf;
                            const double mul = 1-mulsDown*weighting;
                            imBytes[imi] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi]*mul)));
                            imBytes[imi+1] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+1]*mul)));
                            imBytes[imi+2] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+2]*mul)));
                        }
                        if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                            const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                            
                            const int imi = imyi+imx*4;
                            const double weighting = xf*yf;
                            const double mul = 1-mulsDown*weighting;
                            imBytes[imi] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi]*mul)));
                            imBytes[imi+1] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+1]*mul)));
                            imBytes[imi+2] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+2]*mul)));
                        }
                    }
                    if (imy2<=imh) for (int imy = imy1; imy<imy2; imy++) {
                        const int imyi = imy*imw*4;
                        const double yf = ((double)(imy2-1-imy))/(imy2-imy1);
                        for (int imx = imx0; imx<imx1; imx++) {
                            const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                            
                            const int imi = imyi+imx*4;
                            const double weighting = xf*yf;
                            const double mul = 1-mulsDown*weighting;
                            imBytes[imi] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi]*mul)));
                            imBytes[imi+1] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+1]*mul)));
                            imBytes[imi+2] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+2]*mul)));
                        }
                        if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                            const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                            
                            const int imi = imyi+imx*4;
                            const double weighting = xf*yf;
                            const double mul = 1-mulsDown*weighting;
                            imBytes[imi] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi]*mul)));
                            imBytes[imi+1] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+1]*mul)));
                            imBytes[imi+2] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+2]*mul)));
                        }
                    }
                }
            }
            sum=0;
            for (int imy = imy0; imy<imy1; imy++) {
                const int imyi = imy*imw*4;
                for (int imx = imx0; imx<imx1; imx++) {
                    
                    const int imi = imyi+imx*4;
                    const uint8_t r = imBytes[imi], g = imBytes[imi+1], b = imBytes[imi+2];
                    sum += ((uint32_t)r)*2+g+b;
                }
            }
            dprint(" ---> %d (%d = %.1f%%)\n",sum,sum-newSum,100.0*(sum-newSum)/newSum);
            maxErr=fmax(maxErr,100.0*(sum-newSum)/newSum);
        }
        dprint("\n");
    }
    dprint("Max error %.1f%%",maxErr);
    return YES;
}
#undef dprint

+(NSMutableData*)pixelCountsForDataLayerInImage:(NSData*)imageData imageSize:(CGSize)imageSize dataLayerSize:(CGSize)dataLayerSize byteModulus:(uint8_t)byteModulus {
    byteModulus = (byteModulus<sizeof(g_defaultDataLayerByteModulus)/sizeof(g_defaultDataLayerByteModulus[0]) ? g_defaultDataLayerByteModulus[byteModulus] : byteModulus);

    const int dw = (int)round(dataLayerSize.width), dh = (int)round(dataLayerSize.height);
    const int imw = (int)round(imageSize.width), imh = (int)round(imageSize.height);

    if (dw<=0 || dh<=0 || imw<=0 || imh<=0) return nil;

    NSMutableData *ret = [NSMutableData dataWithLength:sizeof(DataLayerPixelCount)*dw*dh];
    
    DataLayerPixelCount *dataCounts = (DataLayerPixelCount*)ret.mutableBytes;
    const uint8_t *imBytes = (const uint8_t*)imageData.bytes;

    int imy1 = 0;
    for (int dy=0; dy<dh; dy++) {
        const int imy0 = imy1; imy1 = (dy+1)*imh/dh;
        const int dyi = dy*dw;
        
        int imx1 = 0;
        for (int dx=0; dx<dw; dx++) {
            const int imx0 = imx1; imx1 = (dx+1)*imw/dw;
            const int di = dyi+dx;
            
            int64_t sum=0;
            const int32_t c=(imy1-imy0)*(imx1-imx0);

//printf("%d,%d,%d %d,%d,%d\n",imx0,imx1,imx2,imy0,imy1,imy2);
            for (int imy = imy0; imy<imy1; imy++) {
                const int imyi = imy*imw*4;
                for (int imx = imx0; imx<imx1; imx++) {
                    const int imi = imyi+imx*4;
                    const uint8_t r = imBytes[imi], g = imBytes[imi+1], b = imBytes[imi+2];
                    sum += ((uint64_t)r)*2+g+b;
                }
            }
            dataCounts[di]=(DataLayerPixelCount){c,sum};

//            printf("[%d,%d] %d %% %dx%d = %d\n",dx,dy,(int32_t)sum,c,byteModulus,(int32_t)sum%(c*byteModulus));
        }
//        printf("\n");
    }
    return ret;
}

+(int)idMarkDataLength {
    static int ret = -1;
    if (ret < 0) ret = (int)[self idMarkData:0].length;
    return ret;
}

static uint32_t s_idMark = 0x7543cf12;// randomish

+(NSData*)idMarkData:(uint32_t)i {
    uint32_t buf[2] = {s_idMark, i};
    NSData *d = [NSData dataWithBytes:buf length:sizeof(buf)];

    return d.eccEncoded;
}

+(int64_t)integerFromIdMarkData:(NSData*)data {
    const int len = self.idMarkDataLength;
    if (data.length<len*8) return -1LL;
    NSData *d = (data.length == len*8 ? data : [data subdataWithRange:NSMakeRange(0, len*8)]);
    d = d.eccBitsDecoded;
    if (!d) return -1LL;
    const uint32_t *buf = (const uint32_t*)d.bytes;
    return (buf[0]==s_idMark ? (int64_t)buf[1] : -1LL);
}

+(NSData*)dataLayerInImage:(NSData*)imageData imageSize:(CGSize)imageSize dataLayerInitialSize:(CGSize)dataLayerSize minDataLayerBytes:(int)minBytes byteModulus:(uint8_t)byteModulus isZipped:(bool)isZipped {
    minBytes = (minBytes ? minBytes : g_defaultMinDataLayerBytes);

    NSMutableData *pixelCounts = [self pixelCountsForDataLayerInImage:imageData imageSize:imageSize dataLayerSize:dataLayerSize byteModulus:byteModulus];
    if (!pixelCounts) {return nil;}

    int dw = (int)round(dataLayerSize.width), dh = (int)round(dataLayerSize.height);
    NSMutableData *dataLayerData = [NSMutableData dataWithLength:dw*dh];

    int idLen = self.idMarkDataLength;
    
    bool combinex = (imageSize.width<imageSize.height);
    while (YES) {
        /*{
            const DataLayerPixelCount *px = (const DataLayerPixelCount*)pixelCounts.bytes;
            for (int y = 0, i=0;y<dh;y++) {
                printf("[%d] ",y);
                for (int x = 0;x<dw;x++,i++) printf("%qx:%x  ",px[i].sum,px[i].pixelCount);
                printf("\n");
            }
        }*/
        for (uint8_t bm = (byteModulus==DataLayer_AnyByteModulus?0:byteModulus); bm<=(byteModulus==DataLayer_AnyByteModulus?2:byteModulus); bm++) {
            [self copyBitsFromPixelCounts:pixelCounts into:dataLayerData byteModulus:bm];
            if (dataLayerData.length<idLen) break;

            [dataLayerData derandomizeOrder];
            
            //printf("data layer in order (bits) [%d]:\n%s\n",(int)dataLayerData.length,dataLayerData.description.UTF8String);
            //printf("   (bytes) [%d]: %s\n",(int)dataLayerData.fromBits.length,dataLayerData.fromBits.description.UTF8String);
            const int64_t len = [self integerFromIdMarkData:dataLayerData];
            if (len>=0) {
                if (len*8>=dataLayerData.length-idLen) return nil;
                NSData *encoded = [dataLayerData subdataWithRange:NSMakeRange(idLen*8, len*8)];
                //printf("data layer encoded [%d]:\n%s\n",(int)encoded.length,encoded.description.UTF8String);
                
                if (encoded&&(s_ref.length*8==encoded.length)) {
                    NSData *encoded2 = s_ref;
                    int c = 0, wrong = 0;
                    const uint8_t *pa = (const uint8_t*)encoded.bytes;
                    const uint8_t *pb = (const uint8_t*)encoded2.bytes;
                    for (int i=(int)MIN(encoded.length,encoded2.length*8)-1; i>=0; i--) {
                        c++;
                        printf("%d",(pa[i]>=0x80)!=((pb[i>>3]&(1<<(i&7)))!=0));
                        wrong+=(pa[i]>=0x80)!=((pb[i>>3]&(1<<(i&7)))!=0);
                    }
                    printf("\nOf %d bits, %d are wrong. Error rate %.3f%%\n",c,wrong,wrong*100.0/c);
                }
                
                NSData *zipped = [encoded eccBitsDecoded];
                //printf("data layer zipped [%d]:\n%s\n",(int)zipped.length,zipped.description.UTF8String);
                NSData *data = (isZipped?zipped.gzipInflate:zipped);
                //printf("data layer [%d]:\n%s\n",(int)data.length,data.description.UTF8String);
                
                return data;
            }
        }
        
        if ((dw*dh/2+7)/8<minBytes) break;
        
        [self combinePixelCountsForDataLayer:pixelCounts size:CGSizeMake(dw,dh) combinex:combinex combiney:!combinex];
        if (combinex) dw>>=1;
        else dh>>=1;
        combinex=!combinex;
    }
    return nil;
}

#define dprint(...) //printf(__VA_ARGS__)
+(void)copyBitsFromPixelCounts:(NSData*)pixelCounts into:(NSMutableData*)data byteModulus:(uint8_t)byteModulus {
    byteModulus = (byteModulus<sizeof(g_defaultDataLayerByteModulus)/sizeof(g_defaultDataLayerByteModulus[0]) ? g_defaultDataLayerByteModulus[byteModulus] : byteModulus);

    const DataLayerPixelCount *counts = (const DataLayerPixelCount*)pixelCounts.bytes;
    uint8_t *bytes = (uint8_t*)data.mutableBytes;
    
    const int len = (int)MIN(data.length,pixelCounts.length/sizeof(DataLayerPixelCount));
    int i=0;
    
    const uint64_t pixMod = byteModulus*4;// i.e. red+red+green+blue
    
    for (; i<len; i++)  {
        const DataLayerPixelCount count=counts[i];
        const int64_t mod = count.pixelCount*pixMod;
        bytes[i] = MIN(0xff,ABS(ABS(((int16_t)((count.sum%mod)*0x200/mod))-0x180)-0x100));
        
        dprint("[%d] %qd %% (%dx%qd=%qd) = %qd (%.2f, %d)\n",i,count.sum,count.pixelCount,pixMod,count.pixelCount*pixMod,count.sum%(count.pixelCount*pixMod),(count.sum%(count.pixelCount*pixMod))/(double)(count.pixelCount*pixMod),bytes[i]);
    }
    data.length = i;
    //printf("%s\n",data.description.UTF8String);
}
#undef dprint


+(bool)combinePixelCountsForDataLayer:(NSMutableData*)pixelCounts size:(CGSize)dataLayerSize combinex:(bool)combinex combiney:(bool)combiney {
    const int dw = (int)round(dataLayerSize.width), dh = (int)round(dataLayerSize.height);

    if (dw<(combinex?2:1) || dh<(combiney?2:1)) return NO;

    DataLayerPixelCount *dataCounts = (DataLayerPixelCount*)pixelCounts.mutableBytes;
    
    int toi=0;
    if (combinex) {
        if (combiney) {
            for (int dy=0; dy<dh; dy+=2) {
                const int dyi = dy*dw;
                for (int dx=0; dx<dw; dx+=2, toi++) {
                    const int di = dyi+dx;
                    const DataLayerPixelCount
                        a = dataCounts[di], b = dataCounts[di+1], c = dataCounts[di+dw], d = dataCounts[di+dw+1];
                    dataCounts[toi]=(DataLayerPixelCount){
                        a.pixelCount+b.pixelCount+c.pixelCount+d.pixelCount,
                        a.sum+b.sum+c.sum+d.sum
                    };
                }
            }
        }
        else {
            for (int dy=0; dy<dh; dy++) {
                const int dyi = dy*dw;
                for (int dx=0; dx<dw; dx+=2, toi++) {
                    const int di = dyi+dx;
                    const DataLayerPixelCount
                        a = dataCounts[di], b = dataCounts[di+1];
                    dataCounts[toi]=(DataLayerPixelCount){
                        a.pixelCount+b.pixelCount,
                        a.sum+b.sum
                    };
                }
            }
        }
    }
    else if (combiney) {
        for (int dy=0; dy<dh; dy+=2) {
            const int dyi = dy*dw;
            for (int dx=0; dx<dw; dx++, toi++) {
                const int di = dyi+dx;
                const DataLayerPixelCount
                    a = dataCounts[di], b = dataCounts[di+dw];
                dataCounts[toi]=(DataLayerPixelCount){
                    a.pixelCount+b.pixelCount,
                    a.sum+b.sum
                };
            }
        }
    }
    else toi=dw*dh;
    pixelCounts.length = sizeof(DataLayerPixelCount)*toi;
    return YES;
}


@end

