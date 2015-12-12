//
//  Util.h
//  Fractal surfer
//
//  Created by Jen on 19/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//



extern NSString * __nonnull memorySummaryString();
#ifdef __cplusplus
#ifdef DEBUG
    extern "C" vm_size_t getFreeMemory();
    extern "C" vm_size_t getUsedMemory();
#endif
#else
#ifdef DEBUG
    extern vm_size_t getFreeMemory();
    extern vm_size_t getUsedMemory();
#endif
#endif

#define _UIColorFromARGB(__argbValue) ({unsigned long ___argbValue = (__argbValue); \
[UIColor colorWithRed:((float)((___argbValue & 0x00FF0000) >> 16))/255.0 \
                green:((float)((___argbValue & 0x0000FF00) >>  8))/255.0 \
                 blue:((float)((___argbValue & 0x000000FF) >>  0))/255.0 \
                alpha:((float)((___argbValue & 0xFF000000L) >>  24))/255.0]; \
})
#define _UIColorFromRGB(__rgbValue) ({unsigned long ___rgbValue = (__rgbValue); \
[UIColor colorWithRed:((float)((___rgbValue & 0x00FF0000) >> 16))/255.0 \
                green:((float)((___rgbValue & 0x0000FF00) >>  8))/255.0 \
                 blue:((float)((___rgbValue & 0x000000FF) >>  0))/255.0 \
                alpha:1.0]; \
})

#define cached_id_return(__ret,...) _cached_id_return(self,__ret,__VA_ARGS__)
#define _cached_id_return(__sync,...) _cached_return(__sync,id,__VA_ARGS__)

#define cached_return(__type,__ret,...) _cached_return(self,__type,__ret,__VA_ARGS__)
#define _cached_return(__sync,__type,__ret,...) do { \
    static __type __cached_return_value = nil; \
    static dispatch_once_t __cached_return_once_token; \
    @synchronized(__sync) { \
        dispatch_once(&__cached_return_once_token, ^{__VA_ARGS__;__cached_return_value=(__ret);}); \
        return(__cached_return_value); \
    } \
} while(NO)


@interface NSString(Will)

-(const void *__nonnull)asVoidPointerKey;

@end

extern unsigned long ARGBFromUIColor(UIColor *__nonnull col);
extern UIColor *__nonnull UIColorFromARGB(unsigned long value);
extern UIColor *__nonnull UIColorFromRGB(unsigned long value);
@interface Util : NSObject

+ (bool) getInsertsAndDeletesWhenChanging:(NSArray*__nullable)from to:(NSArray*__nullable)to inss:(NSArray*__nullable*__nullable)pinss dels:(NSArray*__nullable*__nullable)pdels;
+ (bool) getInsertsAndDeletesAsIndexSetWhenChanging:(NSArray*__nullable)from to:(NSArray*__nullable)to inss:(NSIndexSet*__nullable*__nullable)pinss dels:(NSIndexSet*__nullable*__nullable)pdels;
+ (bool) getInsertsAndDeletesAsIndexPathsInSection:(int)section whenChanging:(NSArray*__nullable)from to:(NSArray*__nullable)to inss:(NSArray*__nullable*__nullable)pinss dels:(NSArray*__nullable*__nullable)pdels;

@end

@interface DebugDict : NSDictionary
@end
@interface DebugArray : NSArray {
    NSArray *__array;
}
@end


@interface NSString(URLEncode)

@property (readonly,nonatomic) NSString*__nonnull urlEncoded,*__nonnull urlDecoded;

@end


@interface NSDictionary(alphaNumEncode)
-(NSString*__nullable)alphaNumZipEncode;
-(NSString*__nullable)alphaNumEncode;
@end
@interface NSData(alphaNumEncode)
-(NSString*__nonnull)alphaNumZipEncode;
-(NSString*__nonnull)alphaNumEncode;
-(NSString*__nonnull)alphaNumEncodeWithZip:(bool)zip;
@end

@interface NSString(alphaNumEncode)

-(NSString*__nullable)alphaNumZipEncode;
-(NSString*__nullable)alphaNumEncode;

-(NSString*__nullable)alphaNumDecodeAsString;
-(NSDictionary*__nullable)alphaNumDecodeAsDictionary;
-(NSMutableData*__nullable)alphaNumDecodeAsData;

@end
