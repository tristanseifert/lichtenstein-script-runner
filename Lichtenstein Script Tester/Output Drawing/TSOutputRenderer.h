//
//  TSOutputRenderer.h
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TSOutputRenderer : NSView

@property (nonatomic) NSUInteger numPixels;
@property (nonatomic) NSMutableData *dataArray;

@end
