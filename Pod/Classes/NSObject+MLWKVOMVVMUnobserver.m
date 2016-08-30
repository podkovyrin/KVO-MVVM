//
//  KVO-MVVM-Unobserver.m
//  Pods
//
//  Created by Anton Bukov on 30.08.16.
//
//

#import <objc/runtime.h>

#import <JRSwizzle/JRSwizzle.h>

#import "NSObject+MLWKVOMVVMUnobserver.h"

static void *MLWKVOMVVMUnobserverContext = &MLWKVOMVVMUnobserverContext;

//

@interface MLWKVOMVVMUnobserver : NSObject

@property (assign, nonatomic) id object;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *strongKeyPaths;

@end

@implementation MLWKVOMVVMUnobserver

- (NSHashTable *)contextsForKeyPath:(NSString *)keyPath observer:(id)observer {
    if (!self.keyPaths) {
        self.keyPaths = [NSMutableDictionary dictionary];
    }
    if (!self.keyPaths[keyPath]) {
        self.keyPaths[keyPath] = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory valueOptions:NSPointerFunctionsStrongMemory];
    }
    if (![self.keyPaths[keyPath] objectForKey:observer]) {
        [self.keyPaths[keyPath] setObject:[NSHashTable hashTableWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality] forKey:observer];
    }
    return [self.keyPaths[keyPath] objectForKey:observer];
}

- (NSHashTable *)contextsForStrongKeyPath:(NSString *)keyPath observer:(id)observer {
    if (!self.strongKeyPaths) {
        self.strongKeyPaths = [NSMutableDictionary dictionary];
    }
    if (!self.strongKeyPaths[keyPath]) {
        self.strongKeyPaths[keyPath] = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
    }
    if (![self.strongKeyPaths[keyPath] objectForKey:observer]) {
        [self.strongKeyPaths[keyPath] setObject:[NSHashTable hashTableWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality] forKey:observer];
    }
    return [self.strongKeyPaths[keyPath] objectForKey:observer];
}

- (void)dealloc {
    for (NSDictionary<NSString *, NSMapTable<id, NSHashTable *> *> *keyPaths in @[ self.keyPaths ?: @{}, self.strongKeyPaths ?: @{} ]) {
        for (NSString *keyPath in keyPaths) {
            NSMapTable<id, NSHashTable *> *observers = keyPaths[keyPath];
            for (NSObject *observer in observers) {
                for (id context in [observers objectForKey:observer]) {
                    if (context != MLWKVOMVVMUnobserverContext) {
                        //NSLog(@"[%@ removeObserver:%p forKeyPath:%@ context: %p", [self class], observer, keyPath, context);
                        [self.object removeObserver:observer forKeyPath:keyPath context:(__bridge void *_Nullable)(context)];
                    }
                    else {
                        //NSLog(@"[%@ removeObserver:%p forKeyPath:%@", [self class], observer, keyPath);
                        [self.object removeObserver:observer forKeyPath:keyPath];
                    }
                }
            }
        }
    }
    self.keyPaths = nil;
    self.strongKeyPaths = nil;
}

@end

//

@interface NSObject (MLWKVOMVVMUnobservable)

@property (readonly, nonatomic) MLWKVOMVVMUnobserver *mvvm_unobserver;

@end

@implementation NSObject (MLWKVOMVVMUnobservable)

@dynamic mvvm_unobserver;

- (id)mvvm_unobserver {
    MLWKVOMVVMUnobserver *unobserver = objc_getAssociatedObject(self, _cmd);
    if (unobserver == nil) {
        unobserver = [[MLWKVOMVVMUnobserver alloc] init];
        unobserver.object = self;
        objc_setAssociatedObject(self, _cmd, unobserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return unobserver;
}

+ (void)load {
    NSError *error;
    if (![self jr_swizzleMethod:@selector(addObserver:forKeyPath:options:context:) withMethod:@selector(mvvm_addObserver:forKeyPath:options:context:) error:&error]) {
        NSLog(@"Swizzling [%@ %@] error: %@", self, NSStringFromSelector(@selector(addObserver:forKeyPath:options:context:)), error);
    }

    if (![self jr_swizzleMethod:@selector(removeObserver:forKeyPath:context:) withMethod:@selector(mvvm_removeObserver:forKeyPath:context:) error:&error]) {
        NSLog(@"Swizzling [%@ %@] error: %@", self, NSStringFromSelector(@selector(removeObserver:forKeyPath:context:)), error);
    }

    if (![self jr_swizzleMethod:@selector(removeObserver:forKeyPath:) withMethod:@selector(mvvm_removeObserver:forKeyPath:) error:&error]) {
        NSLog(@"Swizzling [%@ %@] error: %@", self, NSStringFromSelector(@selector(removeObserver:forKeyPath:)), error);
    }
}

- (void)mvvm_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    //NSLog(@"[%@ addObserver:%p forKeyPath:%@ context: %p", [self class], observer, keyPath, context);
    if ([observer isKindOfClass:NSClassFromString(@"NSKeyValueObservance")]) {
        NSHashTable *strongHashTable = [self.mvvm_unobserver contextsForStrongKeyPath:keyPath observer:observer];
        [strongHashTable addObject:(__bridge id _Nullable)(context ?: MLWKVOMVVMUnobserverContext)];
    }
    else {
        NSHashTable *hashTable = [self.mvvm_unobserver contextsForKeyPath:keyPath observer:observer];
        [hashTable addObject:(__bridge id _Nullable)(context ?: MLWKVOMVVMUnobserverContext)];
    }
    [self mvvm_addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context {
    NSHashTable *hashTable = [self.mvvm_unobserver.keyPaths[keyPath] objectForKey:observer];
    NSHashTable *strongHashTable = [self.mvvm_unobserver.strongKeyPaths[keyPath] objectForKey:observer];
    [hashTable removeObject:(__bridge id _Nullable)(context ?: MLWKVOMVVMUnobserverContext)];
    [strongHashTable removeObject:(__bridge id _Nullable)(context ?: MLWKVOMVVMUnobserverContext)];
    [self mvvm_removeObserver:observer forKeyPath:keyPath context:context];
}

- (void)mvvm_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    NSHashTable *hashTable = [self.mvvm_unobserver.keyPaths[keyPath] objectForKey:observer];
    NSHashTable *strongHashTable = [self.mvvm_unobserver.strongKeyPaths[keyPath] objectForKey:observer];
    [hashTable removeObject:(__bridge id _Nullable)(MLWKVOMVVMUnobserverContext)];
    [strongHashTable removeObject:(__bridge id _Nullable)(MLWKVOMVVMUnobserverContext)];
    [self mvvm_removeObserver:observer forKeyPath:keyPath];
}

@end