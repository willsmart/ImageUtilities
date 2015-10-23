
@interface Viterbi:NSObject
+(double)relativeNoise;
+(void)setRelativeNoise:(double)v;
+(double)signalAmplitude;
+(void)setSignalAmplitude:(double)v;
+(void)setup;
@end

@interface NSData(Viterbi)
@property (readonly,nonatomic) NSMutableData *__nonnull viterbiEncoded,*__nonnull viterbiBitsDecoded;
@end

