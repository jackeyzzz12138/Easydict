//
//  MainWindow.m
//  Bob
//
//  Created by tisfeng on 2022/11/3.
//  Copyright © 2022 ripperhe. All rights reserved.
//

#import "EZFixedQueryWindow.h"

@implementation EZFixedQueryWindow

static EZFixedQueryWindow *_instance;

+ (instancetype)shared {
    if (!_instance) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _instance = [[super allocWithZone:NULL] init];
        });
    }
    return _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self shared];
}

- (instancetype)init {
    if (self = [super initWithWindowType:EZWindowTypeFixed]) {
//        [self standardWindowButton:NSWindowZoomButton].hidden = NO;
//        [self standardWindowButton:NSWindowCloseButton].hidden = NO;
//        [self standardWindowButton:NSWindowMiniaturizeButton].hidden = NO;
    }
    return self;
}

#pragma mark - Rewrite
- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return YES;
}

@end
