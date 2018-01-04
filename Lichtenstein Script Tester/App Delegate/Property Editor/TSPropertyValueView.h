//
//  TSPropertyValueView.h
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TSPropertyValueView : NSTableCellView

@property (nonatomic, copy) void (^valueDidChangeCallback)(TSPropertyValueView *view, NSString *key, NSNumber *newValue);

@property NSNumber *valueNumber;
@property NSString *key;

@end
