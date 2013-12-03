//
//  file_Delegate.m
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import "file_Delegate.h"
#import "file_UIImagePickerControllerViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>

@implementation file_Delegate

- (file_Delegate*) initWithTask:(ForgeTask *)initTask andParams:(id)initParams andType:(NSString *)initType {
	if (self = [super init]) {
		task = initTask;
		params = initParams;
		didReturn = NO;
		type = initType;
		// "retain"
		me = self;
	}	
	return self;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[self cancel];
	[self closePicker];
}

// Callback when an image is chosen/taken with the camera
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	if (keepPicker.sourceType == UIImagePickerControllerSourceTypeCamera) {
		if ([[info objectForKey:@"UIImagePickerControllerMediaType"] isEqualToString:(NSString *)kUTTypeImage]) {
			// Where are we saving
			UIImage *image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
			if ([[params objectForKey:@"saveLocation"] isEqualToString:@"file"]) {
				NSString *path = [NSString stringWithFormat:@"%@/%@.jpg", [[NSFileManager defaultManager] applicationSupportDirectory], [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
				
				[UIImageJPEGRepresentation(image, 0.8) writeToFile:path atomically:YES];
				didReturn = YES;
				[task success:path];
			} else {
				// Save a camera picture in the library then return the save image's URI
				ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
				
				didReturn = YES;
				[library writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)image.imageOrientation completionBlock:^(NSURL* url, NSError* error) {
					[task success:[url absoluteString]];
				}];
			}
		} else if ([[info objectForKey:@"UIImagePickerControllerMediaType"] isEqualToString:(NSString *)kUTTypeMovie]) {
			
			// Save a video in the library then return the saved video's URI
			ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
			
			didReturn = YES;
			[library writeVideoAtPathToSavedPhotosAlbum:[info objectForKey:@"UIImagePickerControllerMediaURL"] completionBlock:^(NSURL* url, NSError* error) {
				[task success:[url absoluteString]];
			}];

		}
	} else {
		// If we already have a URI return it immediately.
		didReturn = YES;
		[task success:[[info objectForKey:@"UIImagePickerControllerReferenceURL"] absoluteString]];
	}
	[self closePicker];
}

- (void) cancel {
	if (!didReturn) {
		didReturn = YES;
		[task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
	}
}

- (void) didDisappear {
	[self cancel];
	// "release"
	me = nil;
}

- (void)closePicker {
	if (([ForgeViewController isIPad]) && keepPicker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
		[keepPopover dismissPopoverAnimated:YES];
	} else {
		[[[ForgeApp sharedApp] viewController] dismissModalViewControllerAnimated:YES];
	}
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex != 0 && buttonIndex != 1) {
		didReturn = YES;
		[task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
		// "release"
		me = nil;
		return;
	}
	file_UIImagePickerControllerViewController *picker = [[file_UIImagePickerControllerViewController alloc] init];
	keepPicker = picker;
	
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] && buttonIndex == 0) {
		picker.sourceType = UIImagePickerControllerSourceTypeCamera;		
	} else {
		picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	}

	// Video or Photo
	picker.mediaTypes = [NSArray arrayWithObjects:type, nil];
	
	if ([type isEqual:(NSString*)kUTTypeMovie] && [params objectForKey:@"videoDuration"] && [params objectForKey:@"videoDuration"] != [NSNull null]) {
		picker.videoMaximumDuration = [[params objectForKey:@"videoDuration"] doubleValue];
	}
	
	picker.delegate = self;
	
	if (([ForgeViewController isIPad]) && picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
		UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:picker];
		keepPopover = popover;
		[popover presentPopoverFromRect:CGRectMake(0.0,0.0,1.0,1.0) inView:[[ForgeApp sharedApp] viewController].view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	} else {	
		dispatch_async(dispatch_get_main_queue(), ^{
			[[[ForgeApp sharedApp] viewController] presentModalViewController:picker animated:NO];
		});
	}
}

@end
