//
//  TSOutputRenderer.m
//  Lichtenstein Script Tester
//
//  Created by Tristan Seifert on 2018-01-03.
//  Copyright © 2018 Tristan Seifert. All rights reserved.
//

#import "TSOutputRenderer.h"

#include "Routine.h"

@implementation TSOutputRenderer

- (void) drawRect:(NSRect) dirtyRect {
    [super drawRect:dirtyRect];
	
	HSIPixel *pixelData = (HSIPixel *) self.dataArray.mutableBytes;
	
	// draw the horizontal lines
	CGFloat width = self.bounds.size.width;
	CGFloat y = self.bounds.size.height;
	
	[[NSColor whiteColor] set];
	NSRectFill(CGRectMake(0, (y - 10), width, 1));
	NSRectFill(CGRectMake(0, (y - 15), width, 1));
	NSRectFill(CGRectMake(0, (y - 20), width, 1));
	NSRectFill(CGRectMake(0, (y - 25), width, 1));
	
	// draw border
	CGFloat height = self.bounds.size.height;
	
	
	[[NSColor controlShadowColor] set];
	NSRectFill(CGRectMake(0, 0, 1, height));
	NSRectFill(CGRectMake(0, (y - 1), width, 1));
	
	NSRectFill(CGRectMake((width - 1), 0, 1, height));
	NSRectFill(CGRectMake(0, 0, width, 1));
	
	// draw each pixel
	for(int i = 0; i < self.numPixels; i++) {
		HSIPixel *pix = &pixelData[i];
		
		CGFloat x = (i * 5) + 1;
		CGRect r = CGRectMake(x, (y - 9), 4, 8);
		
		// conver the hue
		CGFloat h = fmod(pix->h, 360) / 360.f;
		
		// draw the actual color
		NSColor *color = [NSColor colorWithHue:h saturation:pix->s brightness:pix->i alpha:1];
		
		[color set];
		NSRectFill(r);
		
		// draw the hue
		color = [NSColor colorWithHue:h saturation:1 brightness:1 alpha:1];
		r.size.height = 4;
		r.origin.y -= 5;
		
		[color set];
		NSRectFill(r);
		
		// draw the saturation
		color = [NSColor colorWithHue:h saturation:pix->s brightness:1 alpha:1];
		r.origin.y -= 5;
		
		[color set];
		NSRectFill(r);
		
		// draw the brightness/intensity
		color = [NSColor colorWithHue:0 saturation:0 brightness:pix->i alpha:1];
		r.origin.y -= 5;
		
		[color set];
		NSRectFill(r);
		
		// draw a white dividing line
		[[NSColor whiteColor] set];
		NSRectFill(CGRectMake((x + 4), 1, 1, (height - 2)));
	}
}

@end
