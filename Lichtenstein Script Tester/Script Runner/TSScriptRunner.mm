//
//  TSScriptRunner.m
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import "TSScriptRunner.h"

#import "Routine.h"

#include <string>
#include <map>

@interface TSScriptRunner ()

@property Routine *rout;

// redeclare as readwrite
@property (nonatomic, readwrite) CGFloat avgExecutionTime;

@end

@implementation TSScriptRunner

/**
 * Set up some defaults.
 */
- (instancetype) init {
	if(self = [super init]) {
		self.rout = nullptr;
	}
	
	return self;
}

/**
 * When de-allocating, destroy the script context.
 */
- (void) dealloc {
	if(self.rout) {
		delete self.rout;
	}
}

/**
 * De-allocates the script engine.
 */
- (void) teardown {
	if(self.rout) {
		delete self.rout;
		
		self.rout = nullptr;
	}
}

/**
 * Attempts to compile the script
 */
- (BOOL) compileScript:(NSString *) str {
	// delete the old script
	[self teardown];
	
	// compile the new script
	const char *cStr = [str cStringUsingEncoding:NSUTF8StringEncoding];
	std::string cppStr = std::string(cStr);
	
	try {
		self.rout = new Routine(cppStr, "Test Script");
	} catch (Routine::LoadError e) {
		DDLogWarn(@"Couldn't compile script: %s", e.what());
		return NO;
	}
	
	return YES;
}

/**
 * Attaches the given buffer.
 */
- (void) attachBuffer:(NSMutableData *) data {
	HSIPixel *dataPtr = (HSIPixel *) data.mutableBytes;
	NSUInteger numElemenets = data.length / sizeof(HSIPixel);
	DDLogVerbose(@"Attaching buffer with %lu elements", numElemenets);
	
	self.rout->attachBuffer(dataPtr, numElemenets);
}

/**
 * Copies the dictionary into an std::map and stuff.
 */
- (void) setParams:(NSDictionary<NSString *, NSNumber *> *) params {
	__block std::map<std::string, double> paramMap;
	
	[params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL *stop) {
		std::string cppKey = std::string([key cStringUsingEncoding:NSUTF8StringEncoding]);
		double cppValue = value.doubleValue;
		
		paramMap[cppKey] = cppValue;
	}];
	
//	DDLogVerbose(@"Set parameters to: %@", params);
	self.rout->changeParams(paramMap);
}

/**
 * Executes a frame.
 */
- (void) runFrame:(NSUInteger) frame {
	self.rout->execute((int) frame);
	
	[self willChangeValueForKey:@"avgExecutionTime"];
	self.avgExecutionTime = self.rout->getAvgExecutionTime();
	[self didChangeValueForKey:@"avgExecutionTime"];
	
//	DDLogVerbose(@"Frame took %f µS", self.avgExecutionTime);
}

@end
