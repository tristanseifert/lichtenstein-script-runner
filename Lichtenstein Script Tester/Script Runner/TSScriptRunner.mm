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

@interface TSScriptRunner ()

- (void) initScriptContext;

@property Routine *rout;

// redeclare as readwrite
@property (nonatomic, readwrite) CGFloat avgExecutionTime;

@end

@implementation TSScriptRunner

/**
 * Sets up the script context.
 */
- (void) initScriptContext {
	
}

/**
 * Attempts to compile the script
 */
- (BOOL) compileScript:(NSString *) str {
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
 * Executes a frame.
 */
- (void) runFrame:(NSUInteger) frame {
	self.rout->execute((int) frame);
	
	[self willChangeValueForKey:@"avgExecutionTime"];
	self.avgExecutionTime = self.rout->getAvgExecutionTime();
	[self didChangeValueForKey:@"avgExecutionTime"];
	
	DDLogVerbose(@"Frame took %f µS", self.avgExecutionTime);
}

@end
