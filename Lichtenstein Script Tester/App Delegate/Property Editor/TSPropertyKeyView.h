//
//  TSPropertyKeyView.h
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TSPropertyKeyView : NSTableCellView

@property (nonatomic, copy) void (^keyDidChangeCallback)(TSPropertyKeyView *view, NSString *oldKey, NSString *newKey);

@property NSString *keyString;

@end
