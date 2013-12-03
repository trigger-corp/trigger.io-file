//
//  file_PictureTakerDelegate.m
//  ForgeModule
//
//  Created by Connor Dunn on 19/03/2013.
//  Copyright (c) 2013 Trigger Corp. All rights reserved.
//

#import "file_PictureTakerDelegate.h"

@implementation file_PictureTakerDelegate

- (file_PictureTakerDelegate*) initWithTask:(ForgeTask*)initTask {
	if (self = [super init]) {
		task = initTask;
		// "retain"
		me = self;
	}
	return self;
}

- (void)pictureTakerDidEnd:(IKPictureTaker *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSOKButton) {
		NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
		
		NSData *data = [[sheet outputImage] TIFFRepresentation];
		
		if ([data writeToFile:tempFile atomically:YES]) {
			[task success:tempFile];
		} else {
			[task error:@"Unable to save to file" type:@"UNEXPECTED_FAILURE" subtype:nil];
		}
	} else {
		[task error:@"User cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
	}
}

@end
