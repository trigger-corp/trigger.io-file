//
//  file_Delegate.m
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import <CoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>

#import <ForgeCore/ForgeError.h>

#import "file_Util.h"
#import "file_UIImagePickerController.h"

#import "file_Delegate_deprecated.h"



@implementation file_Delegate_deprecated


#pragma mark life-cycle

+ (file_Delegate_deprecated*) withTask:(ForgeTask*)task type:(NSString*)type {
    file_Delegate_deprecated *delegate = [[self alloc] init];
    if (delegate) {
        delegate->me = delegate; // "retain"
        delegate->task = task;
        delegate->type = type;
    }

    return delegate;
}


#pragma mark interface

- (void)openPicker {
    file_UIImagePickerController *picker = [[file_UIImagePickerController alloc] init];
    keepPicker = picker;

    picker.imageExportPreset = UIImagePickerControllerImageURLExportPresetCompatible;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

    // Video or Photo
    picker.mediaTypes = [NSArray arrayWithObjects:type, nil];

    /*if ([type isEqual:(NSString*)kUTTypeMovie] && picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        if ([task.params objectForKey:@"videoDuration"] && [task.params objectForKey:@"videoDuration"] != nil) {
            picker.videoMaximumDuration = [[task.params objectForKey:@"videoDuration"] doubleValue];
        }
        NSString *videoQuality = @"high";
        if ([task.params objectForKey:@"videoQuality"] && [task.params objectForKey:@"videoQuality"] != nil) {
            videoQuality = [task.params objectForKey:@"videoQuality"];
        }
        if ([videoQuality isEqualToString:@"high"]) {
            picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
        } else if ([videoQuality isEqualToString:@"medium"]) {
            picker.videoQuality = UIImagePickerControllerQualityTypeMedium;
        } else {
            picker.videoQuality = UIImagePickerControllerQualityTypeLow;
        }
    }*/
    picker.delegate = self;

    // As of iOS 11 UIImagePickerController runs out of process and we can no longer rely on getting permission request dialogs automatically
    /*[PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            [self->task error:@"Permission denied. User didn't grant access to storage." type:@"EXPECTED_FAILURE" subtype:nil];
            return;
        }*/
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[ForgeApp sharedApp] viewController] presentViewController:picker animated:NO completion:nil];
        });
    //}];
}

// TODO lose this
- (void)closePicker:(void (^ __nullable)(void))success {
    [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
        if (success != nil) success();
    }];
}


#pragma mark callbacks

- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker {
    [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
        [self->task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
    }];
}


- (void) imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo_old:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info {
    [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
        PHAsset *asset = [info objectForKey:UIImagePickerControllerPHAsset];
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
            NSString *videoQuality = [self->task.params objectForKey:@"videoQuality"] ? [self->task.params objectForKey:@"videoQuality"] : @"default";
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


/**
 * Two cases:
 *
 * 1. Gallery Image                 => url (photo-library://image/5B345FEF...) => data [x]
 * 2. Gallery Video                 => url (photo-library://video/5B345FEF...) => data [a]
 */
- (void) imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info {
    [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
        NSError *error = nil;
        ForgeFile *forgeFile = nil;
        
        NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
        if ([type isEqualToString:(NSString*)kUTTypeImage]) {
            forgeFile = [self saveImageForInfo:info error:&error];
            
        } else if ([type isEqualToString:(NSString*)kUTTypeMovie]) {
            forgeFile = [self saveVideoForInfo:info error:&error];
            
        } else {
            return [self->task error:[NSString stringWithFormat:@"Unsupported media type: %@", type] type:@"UNEXPECTED_FAILURE" subtype:nil];
        }

        if (error != nil) {
            return [self->task error:[NSString stringWithFormat:@"Error saving media: %@", error.localizedDescription] type:@"UNEXPECTED_FAILURE" subtype:nil];
        }

        [self->task success:[forgeFile toScriptObject]];
    }];
}


#pragma mark helpers

- (ForgeFile*)saveImageForInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info error:(NSError**)error {
    UIImage *source = [info objectForKey:UIImagePickerControllerOriginalImage];
    if (source == nil) {
        *error = [NSError errorWithDomain:ForgeErrorDomain
                                     code:ForgeErrorCode
                                 userInfo:@{
             NSLocalizedDescriptionKey:@"Failed to obtain image for the selected item"
         }];
        return nil;
    }
    
    ForgeFile *forgeFile = [ForgeFile withEndpointId:ForgeStorage.EndpointIds.Temporary
                                            resource:[ForgeStorage temporaryFileNameWithExtension:@"jpg"]];
    NSURL *destination = [ForgeStorage nativeURL:forgeFile];
    [UIImageJPEGRepresentation(source, 0.9) writeToURL:destination atomically:YES];
    [NSFileManager.defaultManager addSkipBackupAttributeToItemAtURL:destination];
    
    return forgeFile;
}


- (ForgeFile*)saveVideoForInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info error:(NSError**)error {
    NSURL *source = [info objectForKey:UIImagePickerControllerMediaURL];
    if (source == nil) {
        *error = [NSError errorWithDomain:ForgeErrorDomain
                                     code:ForgeErrorCode
                                 userInfo:@{
             NSLocalizedDescriptionKey:@"Failed to obtain url for the selected item"
         }];
        return nil;
    }
    
    NSString *extension = source.pathExtension;
    if (extension == nil) {
        extension = @"mp4";
    }
    
    ForgeFile *forgeFile = [ForgeFile withEndpointId:ForgeStorage.EndpointIds.Temporary
                                            resource:[ForgeStorage temporaryFileNameWithExtension:extension]];
    NSURL *destination = [ForgeStorage nativeURL:forgeFile];
    
    NSData *data = [NSData dataWithContentsOfURL:source];
    if (data == nil) {
        *error = [NSError errorWithDomain:NSItemProviderErrorDomain
                                    code:NSItemProviderUnavailableCoercionError
                                userInfo:@{
            NSLocalizedDescriptionKey:@"Failed to load video data for the selected item"
        }];
        return nil;
    }
    
    if (![data writeToURL:destination atomically:YES]) {
        *error = [NSError errorWithDomain:NSItemProviderErrorDomain
                                    code:NSItemProviderUnavailableCoercionError
                                userInfo:@{
            NSLocalizedDescriptionKey:@"Failed to write video data for the selected item"
        }];
        return nil;
    }
    [[NSFileManager defaultManager] addSkipBackupAttributeToItemAtURL:destination];
    
    return forgeFile;
}

@end
