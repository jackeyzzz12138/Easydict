//
//  EZLinkParser.m
//  Easydict
//
//  Created by tisfeng on 2023/2/25.
//  Copyright © 2023 izual. All rights reserved.
//

#import "EZSchemeParser.h"
#import "EZOpenAIService.h"
#import "EZYoudaoTranslate.h"
#import "EZServiceTypes.h"
#import "EZDeepLTranslate.h"
#import "NSUserDefaults+EZConfig.h"

/// Easydict Scheme: easydict://
static NSString *const kEasydictScheme = @"easydict";

@implementation EZSchemeParser

#pragma mark - Publick

/// Open Easydict URL Scheme.
- (void)openURLScheme:(NSString *)URLScheme completion:(void (^)(BOOL isSuccess, NSString *_Nullable returnValue, NSString *_Nullable actionKey))completion {
    NSString *text = [URLScheme trim];
    
    if (![self isEasydictScheme:text]) {
        completion(NO, @"Invalid Easydict Scheme", nil);
        return;
    }
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:text];
    NSString *action = urlComponents.host;
    NSString *query = urlComponents.query;
    NSDictionary *parameterDict = [self extractQueryParametersFromURLComponents:urlComponents];
    
    NSDictionary *actionDict = [self allowedActionSelectorDict];
    NSArray *allowedActions = actionDict.allKeys;

    if (![allowedActions containsObject:action]) {
        completion(NO, @"Invalid Easydict Action", nil);
        return;
    }
    
    BOOL isSuccess = NO;
    NSString *returnValue = @"Failed";
    NSString *selectorString = actionDict[action];
    SEL selector = NSSelectorFromString(selectorString);
    
    if (selector == @selector(writeKeyValues:)) {
        isSuccess = [self writeKeyValues:parameterDict];
        returnValue = isSuccess ? @"Write Success" : @"Write Failed";
    } else if (selector == @selector(readValueOfKey:)) {
        returnValue = [self readValueOfKey:query];
        isSuccess = returnValue ? YES : NO;
        if (isSuccess) {
            [returnValue copyToPasteboard];
        }
    } else if (selector == @selector(resetUserDefaultsData)) {
        [self resetUserDefaultsData];
        isSuccess = YES;
        returnValue = @"Reset Success";
    } else if (selector == @selector(saveUserDefaultsDataToDownloadFolder)) {
        [self saveUserDefaultsDataToDownloadFolder];
        isSuccess = YES;
        returnValue = @"Save Success";
    }
    
    completion(isSuccess, returnValue, action);
}

- (BOOL)isEasydictScheme:(NSString *)text {
    NSString *urlString = [text trim];
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:urlString];
    NSString *scheme = urlComponents.scheme;
    return [scheme isEqualToString:kEasydictScheme];
}

- (BOOL)isWriteActionKey:(NSString *)actionKey {
    NSArray *writeKeys = @[
        EZWriteKeyValueKey,
        EZResetUserDefaultsDataKey,
    ];
    
    return [writeKeys containsObject:actionKey];
}

#pragma mark -

/// Allowed action keys.
- (NSDictionary<NSString *, NSString *> *)allowedActionSelectorDict {
    return @{
        EZWriteKeyValueKey : NSStringFromSelector(@selector(writeKeyValues:)),
        EZReadValueOfKeyKey : NSStringFromSelector(@selector(readValueOfKey:)),
        EZResetUserDefaultsDataKey : NSStringFromSelector(@selector(resetUserDefaultsData)),
        EZSaveUserDefaultsDataToDownloadFolderKey : NSStringFromSelector(@selector(saveUserDefaultsDataToDownloadFolder)),
    };
}

/// Write key value to NSUserDefaults. easydict://writeKeyValue?EZOpenAIAPIKey=sk-zob
- (BOOL)writeKeyValues:(NSDictionary *)keyValues {
    BOOL handled = NO;
    for (NSString *key in keyValues) {
        NSString *value = keyValues[key];
        if ([self.allowedReadWriteKeys containsObject:key]) {
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
            handled = YES;
        }
    }
    return handled;
}

/// Read value of key from NSUserDefaults. easydict://readValueOfKey?EZOpenAIAPIKey
- (nullable NSString *)readValueOfKey:(NSString *)key {
    if ([self.allowedReadWriteKeys containsObject:key]) {
        return [[NSUserDefaults standardUserDefaults] objectForKey:key];
    } else {
        return nil;
    }
}

- (void)resetUserDefaultsData {
    [[NSUserDefaults standardUserDefaults] resetUserDefaultsData];
}

- (void)saveUserDefaultsDataToDownloadFolder {
    [[NSUserDefaults standardUserDefaults] saveUserDefaultsDataToDownloadFolder];
}


/// Return allowed write keys to NSUserDefaults.
- (NSArray *)allowedReadWriteKeys {
    /**
     easydict://writeKeyValue?EZBetaFeatureKey=1
     
     easydict://writeKeyValue?EZOpenAIAPIKey=sk-zob
     easydict://writeKeyValue?EZOpenAIServiceUsageStatusKey=1
     easydict://writeKeyValue?EZOpenAIDomainKey=api.openai.com
     easydict://readValueOfKey?EZOpenAIDomainKey
     easydict://writeKeyValue?EZOpenAIModelKey=gpt-3.5-turbo
     easydict://writeKeyValue?EZOpenAIDictionaryKey=0
     easydict://writeKeyValue?EZOpenAISentenceKey=0
     
     easydict://writeKeyValue?EZDeepLAuthKey=xxx
     easydict://writeKeyValue?EZDeepLTranslationAPIKey=1
     
     // Youdao TTS
     easydict://writeKeyValue?EZDefaultTTSServiceKey=Youdao
     */
    
    
    NSArray *readWriteKeys = @[
        EZBetaFeatureKey,
        
        EZOpenAIAPIKey,
        EZOpenAIDictionaryKey,
        EZOpenAISentenceKey,
        EZOpenAIServiceUsageStatusKey,
        EZOpenAIDomainKey,
        EZOpenAIModelKey,
        
        EZYoudaoTranslationKey,
        EZYoudaoDictionaryKey,
        
        EZDeepLAuthKey,
        EZDeepLTranslationAPIKey,
        
        EZDefaultTTSServiceKey,
    ];
    
    return readWriteKeys;
}

- (NSArray *)allowedExecuteActionKeys {
    NSArray *actionKeys = @[

        // easydict://saveUserDefaultsDataToDownloadFolder
        EZSaveUserDefaultsDataToDownloadFolderKey,
        
        // easydict://resetUserDefaultsData
        EZResetUserDefaultsDataKey,
        
    ];
    
    return actionKeys;;
}

#pragma mark -

- (NSDictionary *)extractQueryParametersFromURLString:(NSString *)urlString {
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:urlString];
    NSDictionary *queryParameters = [self extractQueryParametersFromURLComponents:urlComponents];
    return queryParameters;
}

// 解析 URL 中的查询参数
- (NSDictionary *)extractQueryParametersFromURLComponents:(NSURLComponents *)urlComponents {
    NSMutableDictionary *queryParameters = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *queryItem in urlComponents.queryItems) {
        NSString *key = queryItem.name;
        NSString *value = queryItem.value;
        
        if (key && value) {
            queryParameters[key] = value;
        }
    }
    
    return [queryParameters copy];
}

#pragma mark -

/// Return key values dict from key-value pairs: key1=value1&key2=value2&key3=value3
- (NSDictionary *)getKeyValues:(NSString *)text {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSArray *keyValueArray = [text componentsSeparatedByString:@"&"];
    for (NSString *keyValue in keyValueArray) {
        NSArray *array = [keyValue componentsSeparatedByString:@"="];
        if (array.count == 2) {
            NSString *key = array[0];
            NSString *value = array[1];
            dict[key] = value;
        }
    }
    return dict;
}

- (NSString *)keyValuesOfServiceType:(EZServiceType)serviceType key:(NSString *)key value:(NSString *)value {
    /**
     easydict://writeKeyValue?ServiceType=OpenAI&ServiceUsageStatus=1
     
     easydict://writeKeyValue?OpenAIServiceUsageStatus=1
     
     easydict://writeKeyValue?OpenAIQueryServiceType=1
     */
    NSString *keyValueString = @"";
    
    NSArray *allowdKeyNames = @[
        EZServiceUsageStatusKey,
        EZQueryServiceTypeKey,
    ];
    
    NSArray *allServiceTypes = [EZServiceTypes allServiceTypes];
    
    BOOL validKey = [allServiceTypes containsObject:serviceType] && [allowdKeyNames containsObject:key];
    
    if (validKey) {
        NSString *keyString = [NSString stringWithFormat:@"%@%@", serviceType, key];
        keyValueString = [NSString stringWithFormat:@"%@=%@", keyString, value];
    }
    
    return keyValueString;
}

@end