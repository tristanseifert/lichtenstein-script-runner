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

- (void) runFrame:(NSUInteger) frame;

@property (nonatomic, readonly) CGFloat avgExecutionTime;

@end
