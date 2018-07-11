//
//  file_Delegate.m
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import "file_Delegate.h"
#import "file_UIImagePickerControllerViewController.h"
#import "file_Util.h"

#import <MobileCoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>

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
    [self closePicker:nil];
}


/**
 * Five cases:
 *
 * 1. Camera Image => File          => url (/path/to/image)                    => data [x]
 * 2. Camera Image => Photo Library => url (photo-library://image/5B345FEF...) => data [x]
 * 3. Camera Video => Photo Library => url (photo-library://video/5B345FEF...) => data [a]
 * 4. Gallery Image                 => url (photo-library://image/5B345FEF...) => data [x]
 * 5. Gallery Video                 => url (photo-library://video/5B345FEF...) => data [a]
 */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    didReturn = YES;
    [self closePicker:^{

        if (self->keepPicker.sourceType == UIImagePickerControllerSourceTypeCamera) {
            if ([[info objectForKey:UIImagePickerControllerMediaType] isEqualToString:(NSString *)kUTTypeImage]) {
                UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];

                // 1. Save as a local file
                if ([[self->params objectForKey:@"saveLocation"] isEqualToString:@"file"]) {
                    NSString *path = [NSString stringWithFormat:@"%@/%@.jpg", [[NSFileManager defaultManager] applicationSupportDirectory], [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
                    [UIImageJPEGRepresentation(image, 0.8) writeToFile:path atomically:YES];
                    [self->task success:path]; // image: /path/to/image
                    return;
                }

                // TODO Write image metadata: http://www.altdevblogaday.com/2011/05/11/adding-metadata-to-ios-images-the-easy-way/
                // 2. Save a camera picture in the library then return the save image's URI
                __block NSString* localIdentifier;
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    PHAssetChangeRequest *assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                    localIdentifier = [[assetChangeRequest placeholderForCreatedAsset] localIdentifier];
                } completionHandler:^(BOOL success, NSError *error) {
                    if (!success) {
                        [self->task error:[error localizedDescription]];
                        return;
                    }
                    NSString *url = [NSString stringWithFormat:@"photo-library://image/%@?ext=JPG", localIdentifier];
                    [self->task success:url]; // image: photo-library://image/5B345FEF-30D7-41C3-BC4E-E11A9F6B4F42/L0/001?ext=JPG
                }];

            } else if ([[info objectForKey:UIImagePickerControllerMediaType] isEqualToString:(NSString *)kUTTypeMovie]) {
                // 3. Save a video in the library then return the saved video's URI
                NSURL *mediaURL = [info objectForKey:UIImagePickerControllerMediaURL];
                __block NSString* localIdentifier;
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    PHAssetChangeRequest *assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:mediaURL];
                    localIdentifier = [[assetChangeRequest placeholderForCreatedAsset] localIdentifier];
                } completionHandler:^(BOOL success, NSError *error) {
                    if (!success) {
                        [self->task error:[error localizedDescription]];
                        return;
                    }
                    NSString *ret = [NSString stringWithFormat:@"photo-library://video/%@?ext=MOV", localIdentifier];
                    [self->task success:ret]; // photo-library://video/5B345FEF-30D7-41C3-BC4E-E11A9F6B4F42/L0/001?ext=MOV
                }];
            }

        } else {  // source is gallery
            PHAsset *asset = nil;
            if (@available(iOS 11_0, *)) {
               asset = [info objectForKey:UIImagePickerControllerPHAsset];
            } else {
                NSURL *referenceURL = [info objectForKey:UIImagePickerControllerReferenceURL];
                PHFetchResult *assetResult = [PHAsset fetchAssetsWithALAssetURLs:@[referenceURL] options:nil];
                if ([assetResult count] >= 1) {
                    asset = [assetResult firstObject];
                }
            }
            if (asset == nil) {
                [self->task error:[NSString stringWithFormat:@"ForgeFile could not locate an asset with reference url: %@", [info objectForKey:@"UIImagePickerControllerReferenceURL"]]];
                return;
            }

            if (asset.mediaType == PHAssetMediaTypeImage) {
                // 4. Select a gallery image and return a reference to the image
                NSString *ret = [NSString stringWithFormat:@"photo-library://image/%@?ext=JPG", [asset localIdentifier]];
                [self->task success:ret]; // photo-library://image/5B345FEF-30D7-41C3-BC4E-E11A9F6B4F42/L0/001?ext=JPG

            } else if (asset.mediaType == PHAssetMediaTypeVideo) {
                // 5. Select a gallery video, potentially transcode it and return a reference to the video
                NSString *videoQuality = [self->params objectForKey:@"videoQuality"] ? [self->params objectForKey:@"videoQuality"] : @"default";
                if ([videoQuality isEqualToString:@"default"]) {
                    NSString *ret = [NSString stringWithFormat:@"photo-library://video/%@?ext=MOV", [asset localIdentifier]];
                    [self->task success:ret]; // photo-library://video/5B345FEF-30D7-41C3-BC4E-E11A9F6B4F42/L0/001?ext=MOV
                } else {
                    [file_Util transcode:asset withTask:self->task videoQuality:videoQuality]; // /path/to/video
                }

            } else {
                [self->task error:[NSString stringWithFormat:@"Unknown media type for selection: %@", [info objectForKey:@"UIImagePickerControllerReferenceURL"]]];
            }

        }
    }];
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


- (void)closePicker:(void (^ __nullable)(void))success {
    if (([ForgeViewController isIPad]) && keepPicker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
        [keepPopover dismissPopoverAnimated:YES];
        if (success != nil) success();
    } else {
        [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
            if (success != nil) success();
        }];
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

    // Going to be wanting the most compatible version for a good many years yet!
    if (@available(iOS 11_0, *)) {
        picker.imageExportPreset = UIImagePickerControllerImageURLExportPresetCompatible;
    }

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] && buttonIndex == 0) {
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    } else {
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    }

    // Video or Photo
    picker.mediaTypes = [NSArray arrayWithObjects:type, nil];

    if ([type isEqual:(NSString*)kUTTypeMovie] && picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        if ([params objectForKey:@"videoDuration"] && [params objectForKey:@"videoDuration"] != nil) {
            picker.videoMaximumDuration = [[params objectForKey:@"videoDuration"] doubleValue];
        }
        NSString *videoQuality = @"high";
        if ([params objectForKey:@"videoQuality"] && [params objectForKey:@"videoQuality"] != nil) {
            videoQuality = [params objectForKey:@"videoQuality"];
        }
        if ([videoQuality isEqualToString:@"high"]) {
            picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
        } else if ([videoQuality isEqualToString:@"medium"]) {
            picker.videoQuality = UIImagePickerControllerQualityTypeMedium;
        } else {
            picker.videoQuality = UIImagePickerControllerQualityTypeLow;
        }
    }
    picker.delegate = self;

    // As of iOS 11 UIImagePickerController runs out of process and we can no longer rely on getting permission request dialogs automatically
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            [self->task error:@"Permission denied. User didn't grant access to storage." type:@"EXPECTED_FAILURE" subtype:nil];
            return;
        }
        [self presentUIImagePickerController:picker];
    }];
}


- (void) presentUIImagePickerController:(UIImagePickerController*)picker {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (([ForgeViewController isIPad]) && picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
            UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:picker];
            self->keepPopover = popover;
            [popover presentPopoverFromRect:CGRectMake(0.0,0.0,1.0,1.0) inView:[[ForgeApp sharedApp] viewController].view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        } else {
            [[[ForgeApp sharedApp] viewController] presentViewController:picker animated:NO completion:nil];
        }
    });
}

@end
