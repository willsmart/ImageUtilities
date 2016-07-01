//
//  Util.h
//  Fractal surfer
//
//  Created by Jen on 19/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#define LERP(a,b,f) \
    ({ __typeof__ (f) __f = (f); \
        ((a)*(1-__f)+(b)*__f); \
    })
#define DELERP(a,b,v) \
    ({ __typeof__ (a) __a = (a); \
        (((v)-__a)/((b)-__a)); \
    })

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


extern NSString *__nullable replaceTokensInFilenameString(NSString *__nullable filename);
extern NSString *__nonnull documentPathForFilename(NSString *__nullable filename);
extern BOOL saveScreenshot(NSString * __nonnull filePath);
extern BOOL saveScreenshotIfChanged(NSString * __nonnull filePath,NSData *__strong __nullable* __nullable screenshotData);
extern NSData *__nullable zippedDirectory(NSArray * __nonnull dirPaths);

extern time_t _DEBLog_time;
#define IF(__dependsOnMacro,...) __dependsOnMacro(__VA_ARGS__)

#define printfLOGIF(__dependsOnMacro,...) IF(__dependsOnMacro,_DEBLog_time=time(nil);printf("%d:%02d:%02d %s\n",(int)((_DEBLog_time/(60*60))%24),(int)((_DEBLog_time/(60))%60),(int)(_DEBLog_time%60),[NSString stringWithFormat:__VA_ARGS__].UTF8String);)
#define printfLOGOBJECTIF(__dependsOnMacro,__object,__depth,...) IF(__dependsOnMacro,printf("%s%s\n",[NSString stringWithFormat:__VA_ARGS__].UTF8String,[PropertyDescription dumpObject:__object filter:^(PropertyDescription *propertyDesc,NSObject *value,NSArray *propertyDescAncestors,NSArray *valueAncestors,NSString *__strong*p_dumpString,NSNumber *__strong*walk){*p_walk=(propertyDescAncestors.count<(__depth))?@(YES):nil;return(YES);}].UTF8String);)
#define printfLOGSYSOBJECTIF(__dependsOnMacro,__object,__depth,...) IF(__dependsOnMacro,printf("%s%s\n",[NSString stringWithFormat:__VA_ARGS__].UTF8String,[PropertyDescription dumpObject:__object filter:^(PropertyDescription *propertyDesc,NSObject *value,NSArray *propertyDescAncestors,NSArray *valueAncestors,NSString *__strong*p_dumpString,NSNumber *__strong*p_walk){*p_walk=@((propertyDescAncestors.count<(__depth)));return(YES);}].UTF8String);)

#define LOGIF(__dependsOnMacro,...) IF(__dependsOnMacro,_DEBLog_time=time(nil);printf("%s",[NSString stringWithFormat:__VA_ARGS__].UTF8String);)
#define LOGOBJECTIF(__dependsOnMacro,__object,__depth,...) IF(__dependsOnMacro,NSLog(__VA_ARGS__,[PropertyDescription dumpObject:__object filter:^(PropertyDescription *propertyDesc,NSObject *value,NSArray *propertyDescAncestors,NSArray *valueAncestors,NSString *__strong*p_dumpString,NSNumber *__strong*walk){*p_walk=(propertyDescAncestors.count<(__depth))?@(YES):nil;return(YES);}].UTF8String);)
#define LOGSYSOBJECTIF(__dependsOnMacro,__object,__depth,...) IF(__dependsOnMacro,NSLog(__VA_ARGS__,[PropertyDescription dumpObject:__object filter:^(PropertyDescription *propertyDesc,NSObject *value,NSArray *propertyDescAncestors,NSArray *valueAncestors,NSString *__strong*p_dumpString,NSNumber *__strong*p_walk){*p_walk=@((propertyDescAncestors.count<(__depth)));return(YES);}].UTF8String);)

#define STARTTIMERIF(__dependsOnMacro,__name) IF(__dependsOnMacro,CFTimeInterval _DEB_timer_start_##__name=CACurrentMediaTime();)
#define FINISHTIMERIF(__dependsOnMacro,__name,...) IF(__dependsOnMacro,CFTimeInterval _DEB_timer_end_##__name=CACurrentMediaTime();NSLog(@" >> %@ took %.4f sec",[NSString stringWithFormat:__VA_ARGS__],_DEB_timer_end_##__name-_DEB_timer_start_##__name);)


#ifdef SHOW_COMPILER_MESSAGES
#define COMPILER_MESSAGE(msg) _Pragma(STR(message(msg)))
#define COMPILER_WARNING(msg) _Pragma(STR(GCC warning(msg)))
#else
#define COMPILER_MESSAGE(msg)
#define COMPILER_WARNING(msg)
#endif
#define STR(X) #X


@interface NSObject (Will)
/**
 Returns the class name as one word, does not include the module prefix for swift objects
 @return this class's name
 */
+(NSString*__nullable)name;

/**
 Returns the class name as one word, does not include the module prefix for swift objects
 @return the object's class name
 */
@property (readonly,nonatomic,nonnull) NSString *className;

+(Class __nullable)byName;

@end


@interface NSString(Will)

-(UIImage *)asImageWithAttributes:(NSDictionary *)attributes size:(CGSize)size;

@property (nonatomic, readonly) Class __nullable getNamedClass;
-(NSObject *__nullable)makeNewByName;

@property (readonly) const void *__nonnull asVoidPointerKey;

-(BOOL)writeToFileCreatingIntermediateDirectories:(NSString *__nonnull)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(NSError *__autoreleasing __nullable *__nullable)error;

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
