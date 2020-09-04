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

#import "file_Storage.h"
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
    picker.mediaTypes = [NSArray arrayWithObjects:self->type, nil];
    picker.delegate = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[[ForgeApp sharedApp] viewController] presentViewController:picker animated:NO completion:nil];
    });
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
                [file_Storage transcode:asset withTask:self->task videoQuality:videoQuality]; // /path/to/video
            }

        } else {
            [self->task error:[NSString stringWithFormat:@"Unknown media type for selection: %@", [info objectForKey:@"UIImagePickerControllerReferenceURL"]]];
        }
    }];
}


- (void) imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info {
    int width = task.params[@"width"] ? [task.params[@"width"] intValue] : 0;
    int height = task.params[@"height"] ? [task.params[@"height"] intValue] : 0;
    NSString *videoQuality = task.params[@"videoQuality"] ? [task.params[@"videoQuality"] stringValue] : @"default";

    [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
        NSError *error = nil;
        ForgeFile *forgeFile = nil;
        
        NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
        
        if ([type isEqualToString:(NSString*)kUTTypeImage]) {
            UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
            if (image == nil) {
                return [self->task error:@"Failed to obtain image for the selected item" type:@"UNEXPECTED_FAILURE" subtype:nil];
            }
            forgeFile = [file_Storage writeUIImageToTemporaryFile:image maxWidth:width maxHeight:height error:&error];
            
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
