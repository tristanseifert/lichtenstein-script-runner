//
//  TSPropertyValueView.m
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import "TSPropertyValueView.h"

static void *TSKVOCtx = &TSKVOCtx;

@implementation TSPropertyValueView

/**
 * Adds a KVO handler.
 */
- (instancetype) initWithCoder:(NSCoder *) decoder {
	if(self = [super initWithCoder:decoder]) {
		[self addObserver:self forKeyPath:@"valueNumber"
				  options:NSKeyValueObservingOptionNew
				  context:TSKVOCtx];
	}
	
	return self;
}

/**
 * Removes KVO handlers when deallocating.
 */
- (void) dealloc {
	[self removeObserver:self forKeyPath:@"valueNumber"];
}

/**
 * Handles KVO notifications.
 */
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if(context != TSKVOCtx) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	} else {
		// the value changed
		NSNumber *new = change[NSKeyValueChangeNewKey];
		
		if(self.valueDidChangeCallback) {
			self.valueDidChangeCallback(self, self.key, new);
		}
	}
}

@end
