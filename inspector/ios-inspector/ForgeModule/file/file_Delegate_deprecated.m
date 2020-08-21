//
//  file_Delegate.m
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import "file_Delegate_deprecated.h"
#import "file_UIImagePickerController.h"
#import "file_Util.h"

#import <CoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>


@implementation file_Delegate_deprecated


#pragma mark life-cycle

- (file_Delegate_deprecated*) initWithTask:(ForgeTask *)initTask andParams:(id)initParams andType:(NSString *)initType {
    if (self = [super init]) {
        task = initTask;
        params = initParams;
        didReturn = NO;
        type = initType;
        me = self; // "retain"
    }
    return self;
}

- (void) cancel {
    if (!didReturn) {
        didReturn = YES;
        [task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self cancel];
    [self closePicker:nil];
}

- (void) didDisappear {
    [self cancel];    
    me = nil; // "release"
}


#pragma mark methods

- (void)openPicker {
    file_UIImagePickerController *picker = [[file_UIImagePickerController alloc] init];
    keepPicker = picker;

    // Going to be wanting the most compatible version for a good many years yet!
    if (@available(iOS 11_0, *)) {
        picker.imageExportPreset = UIImagePickerControllerImageURLExportPresetCompatible;
    }
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

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
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[ForgeApp sharedApp] viewController] presentViewController:picker animated:NO completion:nil];
        });
    }];
}


- (void)closePicker:(void (^ __nullable)(void))success {
    [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
        if (success != nil) success();
    }];
}


#pragma mark callbacks

/**
 * Two cases:
 *
 * 1. Gallery Image                 => url (photo-library://image/5B345FEF...) => data [x]
 * 2. Gallery Video                 => url (photo-library://video/5B345FEF...) => data [a]
 */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    didReturn = YES;
    [self closePicker:^{
        PHAsset *asset = [info objectForKey:UIImagePickerControllerPHAsset];
        /*if (asset == nil) {
            // <face.palm>
            //     on iOS 14, when only giving permission for some resources we
            //     don't get a direct PHAsset reference any more.
            //
            //     instead, we are forced to switch back to UIImagePickerControllerReferenceURL
            //     so that apple can provide a snarky note about "this will be removed, switch to phpicker"
            //
            //     the passive aggression is breathtaking.
            //
            //     why not just state in the documentation: "UIImagePickerController is going away" ?
            // </face.palm>
            NSURL *referenceURL = [info objectForKey:UIImagePickerControllerReferenceURL];
            PHFetchResult *assetResult = [PHAsset fetchAssetsWithALAssetURLs:@[referenceURL] options:nil];
            if ([assetResult count] >= 1) {
                asset = [assetResult firstObject];
            }
        }*/
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
    }];
}



@end
