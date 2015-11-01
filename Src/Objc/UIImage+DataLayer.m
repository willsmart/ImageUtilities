#define PIXELMODOPTIONS @[@40,@80,@120,@200]
int g_defaultMinDataLayerBytes=2000;

@implementation UIImage(DataLayer)

static NSData *s_ref=nil;

+(NSData*)dataLayerInImage:(NSData*)imageData imageSize:(CGSize)imageSize {
    bool xIsMajor = round(imageSize.width)>=round(imageSize.height);
    CGSize dataLayerSize = xIsMajor?CGSizeMake(512,256):CGSizeMake(256,512);
    NSMutableData *pixelCounts = [self pixelCountsForDataLayerInImage:imageData imageSize:imageSize dataLayerSize:dataLayerSize];
    return [pixelCounts eccPixelCountsDecoded:xIsMajor pixelModulusOptions:PIXELMODOPTIONS];
}






+(bool)_addDataLayerToImageData:(NSMutableData*)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*)dataLayerData pixelModulusOptionIndex:(int)pixelModulusOptionIndex {
    NSArray *opts = PIXELMODOPTIONS;
    if (pixelModulusOptionIndex<0 || pixelModulusOptionIndex>=opts.count) return NO;
    [self _addDataLayerToImageData:imageData imageSize:imageSize dataLayerData:dataLayerData pixelModulus:PIXMODFROMOBJECT(opts[pixelModulusOptionIndex])];
    //NSData *d = [self dataLayerInImage:imageData imageSize:imageSize];
    return YES;
}

#define dprint(...) //printf(__VA_ARGS__)
+(bool)_addDataLayerToImageData:(NSMutableData*)imageData imageSize:(CGSize)imageSize dataLayerData:(NSData*)dataLayerData pixelModulus:(EccPixelModulus)pixelModulus {
    const int modLen = PIXMODLEN(pixelModulus);
    NSData *d = [dataLayerData eccGridEncoded:pixelModulus];
    if (!d) return NO;
    
    bool xIsMajor = round(imageSize.width)>=round(imageSize.height);
    int power = (int)round(log2(d.length*8/modLen));
    int minorWidth = 1<<(power/2);
    int majorWidth = 1<<((power+1)/2);
    int dw = (xIsMajor?majorWidth:minorWidth);
    int dh = (xIsMajor?minorWidth:majorWidth);
    
    const int imw = (int)round(imageSize.width), imh = (int)round(imageSize.height);

    if (dw<=0 || dh<=0 || imw<=0 || imh<=0) return NO;

    const uint8_t *dataBytes = (const uint8_t*)d.bytes;
    uint8_t *imBytes = (uint8_t*)imageData.mutableBytes;

    double maxErr=0;
    int imy1 = 0, imy2 = imh/dh;
    for (int dy=0; dy<dh; dy++) {
        const int imy0 = imy1; imy1 = imy2; imy2 = (dy+2)*imh/dh;
        const int dyi = dy*dw;
        
        int imx1 = 0, imx2 = imw/dw;
        for (int dx=0; dx<dw; dx++) {
            const int imx0 = imx1; imx1 = imx2; imx2 = (dx+2)*imw/dw;
            
            for (int _dmi=0;_dmi<modLen;_dmi++) {const int dmi = PIXMODINDEXTOCOL(_dmi, pixelModulus);
                const int di = (dyi+dx)*modLen+_dmi;
                const bool bit = (dataBytes[di>>3]>>(di&7))&1;
                
                int32_t sum=0;
                const int32_t c=(imy1-imy0)*(imx1-imx0);
                double weightedDSum=0, roomAbove = 255, roomBelow = 255;


                switch (dmi) {
                    case 0:case 1:case 2:{
                        for (int imy = imy0; imy<imy1; imy++) {
                            const int imyi = imy*imw*4;
                            const double yf = ((double)(imy+1-imy0))/(imy1-imy0);
                            for (int imx = imx0; imx<imx1; imx++) {
                                const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                                
                                const int imi = imyi+imx*4;
                                const double weighting = xf*yf;
                                const uint8_t v = imBytes[imi+dmi];
                                roomAbove = fmin(roomAbove,(255-v)/weighting);
                                roomBelow = fmin(roomBelow,v/weighting);

                                sum += v;
                                weightedDSum+=weighting;
                            }
                            if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                                const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                                
                                const int imi = imyi+imx*4;
                                const double weighting = xf*yf;
                                const uint8_t v = imBytes[imi+dmi];
                                roomAbove = fmin(roomAbove,(255-v)/weighting);
                                roomBelow = fmin(roomBelow,v/weighting);
                            }
                        }
                        if (imy2<=imh) for (int imy = imy1; imy<imy2; imy++) {
                            const int imyi = imy*imw*4;
                            const double yf = ((double)(imy2-1-imy))/(imy2-imy1);
                            for (int imx = imx0; imx<imx1; imx++) {
                                const double xf = ((double)(imx+1-imx0))/(imx1-imx0);
                                
                                const int imi = imyi+imx*4;
                                const double weighting = xf*yf;
                                const uint8_t v = imBytes[imi+dmi];
                                roomAbove = fmin(roomAbove,(255-v)/weighting);
                                roomBelow = fmin(roomBelow,v/weighting);
                            }
                            if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                                const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                                
                                const int imi = imyi+imx*4;
                                const double weighting = xf*yf;
                                const uint8_t v = imBytes[imi+dmi];
                                roomAbove = fmin(roomAbove,(255-v)/weighting);
                                roomBelow = fmin(roomBelow,v/weighting);
                            }
                        }
                        
                        const int32_t cdiv = c*(&pixelModulus.r)[dmi];
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
                                    imBytes[imi+dmi] = MAX(0,MIN(255,imBytes[imi+dmi]+add));
                                }
                                if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                                    const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                                    
                                    const int imi = imyi+imx*4;
                                    const double weighting = xf*yf;
                                    const int16_t add = (int16_t)round(adds*weighting);
                                    imBytes[imi+dmi] = MAX(0,MIN(255,imBytes[imi+dmi]+add));
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
                                    imBytes[imi+dmi] = MAX(0,MIN(255,imBytes[imi+dmi]+add));
                                }
                                if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                                    const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                                    
                                    const int imi = imyi+imx*4;
                                    const double weighting = xf*yf;
                                    const int16_t add = (int16_t)round(adds*weighting);
                                    imBytes[imi+dmi] = MAX(0,MIN(255,imBytes[imi+dmi]+add));
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
                                    const uint8_t v = imBytes[imi+dmi];

                                    weightedDProdUp+=(0xff-v)*weighting;
                                    weightedDProdDown+=v*weighting;
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
                                        imBytes[imi+dmi] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+dmi])*mul))));
                                    }
                                    if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                                        const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                                        
                                        const int imi = imyi+imx*4;
                                        const double weighting = xf*yf;
                                        const double mul = 1-mulsUp*weighting;
                                        imBytes[imi+dmi] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+dmi])*mul))));
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
                                        imBytes[imi+dmi] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+dmi])*mul))));
                                    }
                                    if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                                        const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                                        
                                        const int imi = imyi+imx*4;
                                        const double weighting = xf*yf;
                                        const double mul = 1-mulsUp*weighting;
                                        imBytes[imi+dmi] = MAX(0,MIN(255,255-((uint8_t)round((255.0-imBytes[imi+dmi])*mul))));
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
                                        imBytes[imi+dmi] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+dmi]*mul)));
                                    }
                                    if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                                        const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                                        
                                        const int imi = imyi+imx*4;
                                        const double weighting = xf*yf;
                                        const double mul = 1-mulsDown*weighting;
                                        imBytes[imi+dmi] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+dmi]*mul)));
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
                                        imBytes[imi+dmi] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+dmi]*mul)));
                                    }
                                    if (imx2<=imw) for (int imx = imx1; imx<imx2; imx++) {
                                        const double xf = ((double)(imx2-1-imx))/(imx2-imx1);
                                        
                                        const int imi = imyi+imx*4;
                                        const double weighting = xf*yf;
                                        const double mul = 1-mulsDown*weighting;
                                        imBytes[imi+dmi] = MAX(0,MIN(255,(uint8_t)round(imBytes[imi+dmi]*mul)));
                                    }
                                }
                            }
                        }
                        sum=0;
                        for (int imy = imy0; imy<imy1; imy++) {
                            const int imyi = imy*imw*4;
                            for (int imx = imx0; imx<imx1; imx++) {
                                
                                const int imi = imyi+imx*4;
                                const uint8_t v = imBytes[imi+dmi];
                                sum += v;
                            }
                        }
                        dprint(" ---> %d (%d:%d = %.1f%%)\n",sum,sum-newSum,cdiv,100.0*(sum-newSum)/cdiv);
                        maxErr=fmax(maxErr,100.0*(sum-newSum)/cdiv);
                    }break;
                    case 3:{
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
                        
                        const int32_t cdiv = c*pixelModulus.w;
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
                        dprint(" ---> %d (%d:%d = %.1f%%)\n",sum,sum-newSum,cdiv,100.0*(sum-newSum)/cdiv);
                        maxErr=fmax(maxErr,100.0*(sum-newSum)/cdiv);
                    }break;
                }
            }
        }
        dprint("\n");
    }
    printf("Max error %.1f%%\n",maxErr);
    return YES;
}
#undef dprint









+(NSMutableData*)pixelCountsForDataLayerInImage:(NSData*)imageData imageSize:(CGSize)imageSize dataLayerSize:(CGSize)dataLayerSize {
    const int dw = (int)round(dataLayerSize.width), dh = (int)round(dataLayerSize.height);
    const int imw = (int)round(imageSize.width), imh = (int)round(imageSize.height);

    if (dw<=0 || dh<=0 || imw<=0 || imh<=0) return nil;

    NSMutableData *ret = [NSMutableData dataWithLength:sizeof(EccPixelCount)*dw*dh];
    
    EccPixelCount *dataCounts = (EccPixelCount*)ret.mutableBytes;
    const uint8_t *imBytes = (const uint8_t*)imageData.bytes;

    int imy1 = 0;
    for (int dy=0; dy<dh; dy++) {
        const int imy0 = imy1; imy1 = (dy+1)*imh/dh;
        const int dyi = dy*dw;
        
        int imx1 = 0;
        for (int dx=0; dx<dw; dx++) {
            const int imx0 = imx1; imx1 = (dx+1)*imw/dw;
            const int di = dyi+dx;
            
//printf("%d,%d,%d %d,%d,%d\n",imx0,imx1,imx2,imy0,imy1,imy2);
            EccPixelCount count={(imy1-imy0)*(imx1-imx0),0,0,0,0};
            for (int imy = imy0; imy<imy1; imy++) {
                const int imyi = imy*imw*4;
                for (int imx = imx0; imx<imx1; imx++) {
                    const int imi = imyi+imx*4;
                    count.r += imBytes[imi];
                    count.g += imBytes[imi+1];
                    count.b += imBytes[imi+2];
                }
            }
            count.w = count.r*2+count.g+count.b;
            dataCounts[di]=count;

//            printf("[%d,%d] %d %% %dx%d = %d\n",dx,dy,(int32_t)sum,c,byteModulus,(int32_t)sum%(c*byteModulus));
        }
//        printf("\n");
    }
    return ret;
}


@end

