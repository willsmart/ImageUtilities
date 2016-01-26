#import "NSData+MD5.h"
#import <CommonCrypto/CommonDigest.h>
// thank you Rob Keniger for a little solution
// http://stackoverflow.com/questions/2018550/how-do-i-create-an-md5-hash-of-a-string-in-cocoa

@implementation NSData (MMAdditions)
-(NSString*)md5hash {
    unsigned char md5[CC_MD5_DIGEST_LENGTH];
    CC_MD5(self.bytes, (CC_LONG)self.length, md5);
    return [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        md5[0], md5[1], md5[2], md5[3],
        md5[4], md5[5], md5[6], md5[7],
        md5[8], md5[9], md5[10], md5[11],
        md5[12], md5[13], md5[14], md5[15]
    ];
}
@end
