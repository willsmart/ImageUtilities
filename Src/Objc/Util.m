//
//  Util.m
//  Fractal surfer
//
//  Created by Jen on 19/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//
#import <mach/mach.h>

#import "NSData+Compression.h"


NSString *memorySummaryString() {
#ifdef DEBUG
    NSString *ret = [NSString stringWithFormat:@"(%fMB used, %fMB free)", getUsedMemory()/(1024.0*1024.0), getFreeMemory()/(1024.0*1024.0)];
    return ret;
#else
    return @"?";
#endif
}

#ifdef DEBUG
    vm_size_t getFreeMemory() {
        mach_port_t host_port = mach_host_self();
        mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
        vm_size_t pagesize;
        vm_statistics_data_t vm_stat;

        host_page_size(host_port, &pagesize);
        (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
        return vm_stat.free_count * pagesize;
    }

    vm_size_t getUsedMemory() {
        struct task_basic_info info;
        mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
        kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
        return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
    }
#endif

UIColor *UIColorFromARGB(unsigned long value) {return _UIColorFromARGB(value);}
UIColor *UIColorFromRGB(unsigned long value) {return _UIColorFromRGB(value);}

unsigned long ARGBFromUIColor(UIColor *__nonnull col) {
    CGFloat r,g,b,a;
    [col getRed:&r green:&g blue:&b alpha:&a];
    return
      (((((MAX(0,MIN(255,(int)round(a*255.0)))<<8)|
           MAX(0,MIN(255,(int)round(r*255.0))))<<8)|
           MAX(0,MIN(255,(int)round(g*255.0))))<<8)|
           MAX(0,MIN(255,(int)round(b*255.0)));
}

@implementation NSString(Will)

-(const void *)asVoidPointerKey {return NSSelectorFromString(self);}

@end

@implementation Util



+ (bool) getInsertsAndDeletesAsIndexSetWhenChanging:(NSArray*)from to:(NSArray*)to inss:(NSIndexSet**)pinss dels:(NSIndexSet**)pdels {
    NSMutableArray *inss,*dels;
    if (![Util getInsertsAndDeletesWhenChanging:from to:to inss:&inss dels:&dels]) return(nil);
    NSMutableIndexSet *s=[NSMutableIndexSet indexSet];
    for (NSNumber *num in dels) [s addIndex:num.intValue];
    *pdels=s;
    s=[NSMutableIndexSet indexSet];
    for (NSNumber *num in inss) [s addIndex:num.intValue];
    *pinss=s;
    return(YES);
}
+ (bool) getInsertsAndDeletesAsIndexPathsInSection:(int)section whenChanging:(NSArray*)from to:(NSArray*)to inss:(NSArray**)pinss dels:(NSArray**)pdels {
    if (![Util getInsertsAndDeletesWhenChanging:from to:to inss:pinss dels:pdels]) return(nil);
    NSMutableArray *dels=[NSMutableArray array];
    NSMutableArray *inss=[NSMutableArray array];
    for (NSNumber *num in *pdels) [dels addObject:[NSIndexPath indexPathForRow:num.intValue inSection:section]];
    for (NSNumber *num in *pinss) [inss addObject:[NSIndexPath indexPathForRow:num.intValue inSection:section]];
    *pinss=inss;
    *pdels=dels;
    return(YES);
}


+ (bool)objectOrString:(id)a equals:(id)b {
    if ([a respondsToSelector:@selector(isEqualToString:)]&&[b respondsToSelector:@selector(isEqualToString:)]) return([((NSString*)a) isEqualToString:(NSString*)b]);
    else return(a==b);
}

+ (bool) getInsertsAndDeletesWhenChanging:(NSArray*)from to:(NSArray*)to inss:(NSArray**)pinss dels:(NSArray**)pdels {
    NSMutableArray *dels=[NSMutableArray array];
    NSMutableArray *inss=[NSMutableArray array];

    *pinss=inss;
    *pdels=dels;
    
    if (from==nil) {
        if (to==nil) return(false);
        else {
            for (int i=0;i<to.count;) [inss addObject:[NSNumber numberWithInt:i++]];
            return(to.count>0);
        }
    }
    else if (to==nil) {
        for (int i=0;i<from.count;) [dels addObject:[NSNumber numberWithInt:i++]];
        return(from.count>0);
    }
    else {
        int toi=0,fromi=0;
        while ((toi<[to count])||(fromi<[from count])) {
            char op=0;
            if (fromi>=[from count]) op='i';
            else if (toi>=[to count]) op='d';
            else if ([Util objectOrString:[from objectAtIndex:fromi] equals:[to objectAtIndex:toi]]) op=0;
            else for (int j=1;;j++) {
                if (toi+j>=[to count]) {op='d';break;}
                else if (fromi+j>=[from count]) {op='i';break;}
                else if ([Util objectOrString:[from objectAtIndex:fromi] equals:[to objectAtIndex:toi+j]]) {op='i';break;}
                else if ([Util objectOrString:[from objectAtIndex:fromi+j] equals:[to objectAtIndex:toi]]) {op='d';break;}
            }
            if (op=='d') {
                [dels insertObject:[NSNumber numberWithInt:fromi] atIndex:0];
                fromi++;
            }
            else if (op=='i') {
                [inss addObject:[NSNumber numberWithInt:toi]];
                toi++;
            }
            else {fromi++;toi++;}
        }
        return(inss.count||dels.count);
    }
    
    
                
}




@end



@implementation DebugDict
-(void)dealloc {
}
@end

@implementation DebugArray
-(instancetype)initWithObjects:(const id [])objects count:(NSUInteger)cnt {
    if (!(self=[super init])) return nil;
    __array = [[NSArray alloc] initWithObjects:objects count:cnt];
    return self;
}
-(instancetype)init {
    if (!(self=[super init])) return nil;
    __array = NSArray.array;
    return self;
}
-(NSUInteger)count {
    return __array.count;
}
-(id)objectAtIndex:(NSUInteger)index {
    return [__array objectAtIndex:index];
}

-(void)dealloc {
}
@end

/*

@implementation NSData(resizeim)

-(NSData*)resizedImageFromSize:(CGSize)fromSize toSize:(CGSize)toSize {
    int fw = (int)round(fromSize.width),fh = (int)round(fromSize.height), tw = (int)round(toSize.width),th = (int)round(toSize.height);
    NSMutableData *ret=[NSMutableData dataWithLength:pixBytes*tw*th];
    const uint8_t *ib = self.bytes;
    uint8_t *ob = ret.mutableBytes;
    
    double addfy = ((double)fh)/th;
    double addfx = ((double)fw)/tw;
    
    double fy=0,fx=0;
    int fx1=-1,fy1=-1;
    for (int ty = 0,ti = 0; ty<th; ty++) {
        const int fy0=fy1+1;
        fy1 = MIN(fh-1,(int)floor(fy+=addfy));
        for (int tx = 0; tx<tw; tx++, ti+=4) {
            fx1 = MIN(fw-1,(int)floor(fx+=addfx));
            ob[ti]=(uint16_t)
            for (int pi = 0; pi<pixBytes; pi++)
        
    int ty2=0;
    for (double ffy = 0, fty = 0;; ffy+=addfy, fty+=addty) {
        const int fy = MIN(fh-1,(int)round(ffy)),ty = MIN(th-1,(int)round(fty));
        
        int fi = fy*fw*pixBytes,ti = ty*tw*pixBytes;
        
        int tx2=0,fx=0;
        for (double ffx = addfx, ftx = addtx;; ffx+=addfx, ftx+=addtx) {
            const int fx = MIN(fw-1,(int)round(ffx)),tx = MIN(tw-1,(int)round(ftx));
            memcpy(ob+ti,ib+fi,pixBytes*(
            if (fx-fx2==tx-tx2) {
                tx3 = tx; fx3 = fx;
                continue;
            }
            else if (tx3!=tx2) {
                if (tx3-tx2==1) {
                    
                
                
@end

*/

@implementation NSString(URLEncode)

-(NSString*)urlEncoded {
    static NSCharacterSet *s_allowed = nil;
    if (!s_allowed) s_allowed = [NSCharacterSet characterSetWithCharactersInString:@"'!*'();:@&=+$,/?%#[]"].invertedSet;
    return [self stringByAddingPercentEncodingWithAllowedCharacters:s_allowed];
}

-(NSString*)urlDecoded {
    return [self stringByRemovingPercentEncoding];
}


@end
/*
a-z 26
A-z 26 52
0-9 10 62
-_ 2 64 -> 6 bit per c

4 char = 24 = 3 bytes
*/





@implementation NSDictionary(alphaNumEncode)
-(NSString*)alphaNumZipEncode {
    NSError *err=nil;
    return [NSJSONSerialization dataWithJSONObject:self options:0 error:&err].alphaNumZipEncode;
}
-(NSString*)alphaNumEncode {
    NSError *err=nil;
    return [NSJSONSerialization dataWithJSONObject:self options:0 error:&err].alphaNumEncode;
}
@end

@implementation NSData(alphaNumEncode)
-(NSString*)alphaNumZipEncode {
    return [self.tightGzipDeflate alphaNumEncodeWithZip:YES];
}
-(NSString*)alphaNumEncode {
    return [self alphaNumEncodeWithZip:NO];
}

#define ENCODEINT(__b) ({const uint32_t b=(const uint32_t)(__b);s_bitsToChar[b&0x3f]|((s_bitsToChar[(b>>6)&0x3f]|((s_bitsToChar[(b>>12)&0x3f]|(s_bitsToChar[(b>>18)&0x3f]<<8))<<8))<<8);})
#define ENCODEBYTES(__pb) ENCODEINT(*(const uint32_t*)(__pb))
-(NSString*)alphaNumEncodeWithZip:(bool)zip {
    static uint32_t s_bitsToChar[0x40] = {0};
    if (!s_bitsToChar[0]) {
        int i=0;
        for (char j='0'; j<='9'; j++) s_bitsToChar[i++]=j;
        for (char j='A'; j<='Z'; j++) s_bitsToChar[i++]=j;
        for (char j='a'; j<='z'; j++) s_bitsToChar[i++]=j;
        s_bitsToChar[i++]='-';
        s_bitsToChar[i++]='_';
    }
    NSMutableData *d = [NSMutableData dataWithLength:4+4*((self.length+2)/3)];
    const uint8_t *ib = (const uint8_t*)self.bytes;
    char *oc = (char *)d.mutableBytes;
    uint32_t *ob = (uint32_t*)oc;
    *(ob++)=ENCODEINT((self.length<<1)|(zip?1:0));
    int i;
    for (i=0;i<self.length-2;i+=3) {
        *(ob++)=ENCODEBYTES(ib+i);
    }
    if (i+1<self.length) {
        *(ob++)=ENCODEINT(*(const uint16_t*)(ib+i));
    }
    else if (i<self.length) {
        *(ob++)=ENCODEINT(*(const uint8_t*)(ib+i));
    }
    if (ob!=d.mutableBytes+d.length) {
        NSLog(@"alphaNumEncode is broken");
    }
    //for (int i = 0;i<d.length-1;i++) {
    //    printf("[%d](%d)'%c' ",i,oc[i],oc[i]<' '?'x':oc[i]);
    //}
    //printf("\n");
    NSString *ret=[NSString.alloc initWithData:d encoding:NSASCIIStringEncoding];
    return ret;
}
#undef ENCODEINT
#undef ENCODEBYTES
@end





@implementation NSString(alphaNumEncode)
-(NSString*)alphaNumZipEncode {
    return [self dataUsingEncoding:NSUTF8StringEncoding].alphaNumZipEncode;
}
-(NSString*)alphaNumEncode {
    return [self dataUsingEncoding:NSUTF8StringEncoding].alphaNumEncode;
}


-(NSString*)alphaNumDecodeAsString {
    NSData *d = self.alphaNumDecodeAsData;
    return d?[NSString.alloc initWithData:d encoding:NSUTF8StringEncoding]:nil;
}


-(NSDictionary*)alphaNumDecodeAsDictionary {
    NSData *d = self.alphaNumDecodeAsData;
    NSError *err=nil;
    return d?[NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingAllowFragments error:&err]:nil;
}



#define DECODEINT(__b) ({const uint32_t b=(const uint32_t)(__b);s_charToBits[b&0xff]|((s_charToBits[(b>>8)&0xff]|((s_charToBits[(b>>16)&0xff]|(s_charToBits[(b>>24)&0xff]<<6))<<6))<<6);})
#define DECODEBYTES(__pb) DECODEINT(*(const uint32_t*)(__pb))
-(NSData*)alphaNumDecodeAsData {
    NSData *me = [self dataUsingEncoding:NSASCIIStringEncoding];
    if ((!me) || me.length<4 || (me.length&3)) {return nil;}
    
    static uint32_t s_charToBits[0x100] = {0};
    if (!s_charToBits[0]) {
        memset(s_charToBits,0,sizeof(s_charToBits));
        int i=0;
        for (char j='0'; j<='9'; j++) s_charToBits[j]=i++;
        for (char j='A'; j<='Z'; j++) s_charToBits[j]=i++;
        for (char j='a'; j<='z'; j++) s_charToBits[j]=i++;
        s_charToBits['-']=i++;
        s_charToBits['_']=i++;
    }

    const uint32_t *ib = (const uint32_t*)me.bytes;
    uint32_t len = DECODEBYTES(ib);ib++;
    bool zip=(len&1);len>>=1;
    
    if (len>((self.length-4)/4)*3) {
        return nil;
    }
    
    NSMutableData *d = [NSMutableData dataWithLength:len];
    uint8_t *ob = (uint8_t*)d.mutableBytes;

    int i;
    for (i=0;i<d.length-3;i+=3) {
        *(uint32_t*)(ob+i)=DECODEBYTES(ib);ib++;
    }
    if (i<d.length) {
        uint32_t b = DECODEBYTES(ib);ib++;
        do {
            ob[i++]=b&0xff;
            b>>=8;
        } while (i<d.length);
    }
    return zip?d.gzipInflate:d;
}

#undef DECODEINT
#undef DECODEBYTES

    
    






@end