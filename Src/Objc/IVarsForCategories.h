//
//  IVarsForCategories.h
//
//  Created by Will Smart on 23/05/14.
//  Copyright (c) 2014 Social Code. All rights reserved.
//

// this can be used to make it easier to fake an ivar in a category
// eg
// @property (strong) NSString *astring;    in the interface of a category, and..
// synthesize_fake_ivar_property(NSString,astring,Astring);   in the implementation
//
// then make the astring backed by storage in this singleton class (categories can't create proper ivars to store things in the way that normal classes would)

#define synthesize_fake_ivar_property(__type,__name,__capitalizedName) \
-(__type*)__name { \
    return(get_fake_ivar(self, @selector(__name), __type.class)); \
} \
-(void)set##__capitalizedName:(__type *)__name { \
    set_fake_ivar(self, @selector(__name), __name); \
}

extern id get_fake_ivar(id object,const void *key,Class kindOfClass);
extern void set_fake_ivar(id object,const void *key,NSObject *value);
extern void set_weak_fake_ivar(id object,const void *key,NSObject *value);

@interface Utility_IVarsForCategories : NSObject

+(id)getPropertyWithClass:(Class)kindOfClass forKey:(const void*)key object:(id)object;
+(void)setProperty:(NSObject*)value forKey:(const void*)key object:(id)object;
+(void)setWeakProperty:(NSObject*)value forKey:(const void*)key object:(id)object;

@end



/* Overridable subclass for base class */
@interface IVarsForCategories : Utility_IVarsForCategories
@end

