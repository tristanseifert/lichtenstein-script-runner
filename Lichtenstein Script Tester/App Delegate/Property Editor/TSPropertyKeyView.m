//
//  TSPropertyKeyView.m
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import "TSPropertyKeyView.h"

static void *TSKVOCtx = &TSKVOCtx;

@implementation TSPropertyKeyView

/**
 * Adds a KVO handler.
 */
- (instancetype) initWithCoder:(NSCoder *) decoder {
	if(self = [super initWithCoder:decoder]) {
		[self addObserver:self forKeyPath:@"keyString"
				  options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
				  context:TSKVOCtx];
	}
	
	return self;
}

/**
 * Removes KVO handlers when deallocating.
 */
- (void) dealloc {
	[self removeObserver:self forKeyPath:@"keyString"];
}

/**
 * Handles KVO notifications.
 */
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if(context != TSKVOCtx) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	} else {
		// the key changed
		NSString *old = change[NSKeyValueChangeOldKey];
		NSString *new = change[NSKeyValueChangeNewKey];
		
//		DDLogVerbose(@"Key changed: %@ -> %@", old, new);
		
		if(self.keyDidChangeCallback && ![old isEqualToString:new]) {
			self.keyDidChangeCallback(self, old, new);
		}
	}
}

@end
