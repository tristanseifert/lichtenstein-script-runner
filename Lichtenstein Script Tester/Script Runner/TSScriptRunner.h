//
//  TSScriptRunner.h
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TSScriptRunner : NSObject

- (BOOL) compileScript:(NSString *) str;
- (void) attachBuffer:(NSMutableData *) data;
- (void) runFrame:(NSUInteger) frame;

- (void) setParams:(NSDictionary<NSString *, NSNumber *> *) params;

- (void) teardown;

@property (nonatomic, readonly) CGFloat avgExecutionTime;

@end
