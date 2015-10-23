//
//  IVarsForCategories.m
//
//  Created by Will Smart on 23/05/14.
//  Copyright (c) 2014 Social Code. All rights reserved.
//

id get_fake_ivar(id object,const void *key,Class kindOfClass) {
    return([IVarsForCategories getPropertyWithClass:kindOfClass forKey:key object:object]);
}
void set_fake_ivar(id object,const void *key,NSObject *value) {
    [IVarsForCategories setProperty:value forKey:key object:object];
}
void set_weak_fake_ivar(id object,const void *key,NSObject *value) {
    [IVarsForCategories setWeakProperty:value forKey:key object:object];
}

@protocol IVarsForCategories_selectors
-(void)IVarsForCategories_nilkey;
@end

/* Overridable subclass for base class */
@implementation IVarsForCategories
@end



@implementation Utility_IVarsForCategories



+(IVarsForCategories*)instance {
    cached_id_return([[IVarsForCategories alloc] init___private]);
}

-(id)init {
    return(nil);
}

-(instancetype)init___private {
    return([super init]);
}


+(id)getPropertyWithClass:(Class)kindOfClass forKey:(const void*)key object:(id)object {
    if (object) {
        if (!key) key=@selector(IVarsForCategories_nilkey);
        id ret=objc_getAssociatedObject(object, key);
        return(kindOfClass&&![ret isKindOfClass:kindOfClass]?nil:ret);
    }
    else return(nil);
}

+(void)setProperty:(NSObject *)value forKey:(const void*)key object:(id)object {
    if (object) {
        if (!key) key=@selector(IVarsForCategories_nilkey);
        objc_setAssociatedObject(object, key, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+(void)setWeakProperty:(NSObject *)value forKey:(const void*)key object:(id)object {
    if (object) {
        if (!key) key=@selector(IVarsForCategories_nilkey);
        objc_setAssociatedObject(object, key, value, OBJC_ASSOCIATION_ASSIGN);
    }
}

@end
