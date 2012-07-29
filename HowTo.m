HowTo -- Helpful Stuff
======================

My main resource for reverse engineering UICollection is [https://github.com/steipete/iOS6-Runtime-Headers](https://github.com/steipete/iOS6-Runtime-Headers).

// For debugging purposes only
``` objective-c
#ifdef DEBUG
NSString *_PSPDFPrintIvars(id obj, NSMutableSet *recursiveSet);
void PSPDFPrintIvars(id obj, BOOL printRecursive) {
    NSString *ivarString = _PSPDFPrintIvars(obj, printRecursive ? [NSMutableSet set] : nil);
    NSLog(@"%@", ivarString);
}

NSMutableDictionary *_PSDPFConvertIvarsToDictionary(Class class, id obj);
NSMutableDictionary *_PSDPFConvertIvarsToDictionary(Class class, id obj) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(class, &ivarCount);
    for (int i = 0; i < ivarCount; i++) {
        NSString *name = @(ivar_getName(ivars[i]));
        id value;
        @try { value = [obj valueForKey:name]; }
        @catch (NSException *exception) {
            value = [exception reason];
        }
        value = value ?: [NSNull null];
        [dict setObject:value forKey:name];
    }
    free(ivars);
    return dict;
}

NSString *_PSPDFPrintIvars(id obj, NSMutableSet *recursiveSet) {
    NSMutableString *string = [NSMutableString string];
    [recursiveSet addObject:obj];

    // query ivar list
    NSMutableSet *ivarDictionaries = [NSMutableSet set];
    NSMutableDictionary *dict = _PSDPFConvertIvarsToDictionary([obj class], obj);
    Class superClass = class_getSuperclass([obj class]);
    while(superClass && ![superClass isEqual:[NSObject class]]) {
        NSDictionary *superClassIvarDict =  _PSDPFConvertIvarsToDictionary(superClass, obj);
        if ([superClassIvarDict count]) {
            dict[NSStringFromClass(superClass)] = superClassIvarDict;

            if ([NSStringFromClass(superClass) hasPrefix:@"UICollection"] || [NSStringFromClass(superClass) hasPrefix:@"_UI"]) {
                [ivarDictionaries addObject:superClassIvarDict];
            }
        }
        superClass = class_getSuperclass(superClass);
    }
    if ([dict count]) {
        [string appendFormat:@"<%@= %@>", NSStringFromClass([obj class]), [dict description]];
    }
    // dig deeper if recursive is enabled
    if (recursiveSet) {
        [dict enumerateKeysAndObjectsUsingBlock:^(id key, id dictObj, BOOL *stop) {
            if ([ivarDictionaries containsObject:dictObj]) {
                [dictObj enumerateKeysAndObjectsUsingBlock:^(id key, id dictObj, BOOL *stop) {

                    if (![recursiveSet containsObject:dictObj] && (![dictObj isKindOfClass:[NSDictionary class]] || [dictObj count] > 0) && ![dictObj isKindOfClass:[NSSet set]] && ![dictObj isKindOfClass:NSClassFromString(@"NSConcreteValue")]) {
                        if ([[dictObj class] conformsToProtocol:@protocol(NSFastEnumeration)]) {
                            for (id anObj in dictObj) {
                                [string appendString:_PSPDFPrintIvars(anObj, recursiveSet)];
                            }
                        }else {
                            [string appendString:_PSPDFPrintIvars(dictObj, recursiveSet)];
                        }
                    }
                }];
            }else {
                if (![recursiveSet containsObject:dictObj] && (![dictObj isKindOfClass:[NSDictionary class]] || [dictObj count] > 0) && ![dictObj isKindOfClass:[NSSet set]] && ![dictObj isKindOfClass:NSClassFromString(@"NSConcreteValue")]) {
                    if ([[dictObj class] conformsToProtocol:@protocol(NSFastEnumeration)]) {
                        for (id anObj in dictObj) {
                            [string appendString:_PSPDFPrintIvars(anObj, recursiveSet)];
                        }
                    }else {
                        [string appendString:_PSPDFPrintIvars(dictObj, recursiveSet)];
                    }
                }
            }
        }];
    }

    // custom stuff (e.g. get a id * variable that's not KVO compliant)
    if([NSStringFromClass([obj class]) isEqualToString:@"UICollectionViewData"]) {
        id *outvalue;
        object_getInstanceVariable(obj, "_globalItems", (void **)&outvalue);
        NSLog(@"done");
    }
    return string;
}
#endif
```
