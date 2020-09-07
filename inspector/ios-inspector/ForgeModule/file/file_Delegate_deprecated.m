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
    
    [[[ForgeApp sharedApp] viewController] presentViewController:picker animated:NO completion:nil];
}


#pragma mark callbacks

- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker {
    [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
        [self->task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
    }];
}


- (void) imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info {
    int selectionLimit = task.params[@"selectionLimit"] ? [task.params[@"selectionLimit"] intValue] : 1;
    int width = task.params[@"width"] ? [task.params[@"width"] intValue] : 0;
    int height = task.params[@"height"] ? [task.params[@"height"] intValue] : 0;
    NSString *videoQuality = task.params[@"videoQuality"] ? (NSString*)task.params[@"videoQuality"] : @"default";

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
            // TODO until Apple allow us to transcode PHPicker results directly
            if (![videoQuality isEqualToString:@"default"]) {
                PHAsset *asset = [info objectForKey:UIImagePickerControllerPHAsset];
                [file_Storage transcode:asset withTask:self->task videoQuality:videoQuality];
                return;
            }
            forgeFile = [self saveVideoForInfo:info videoQuality:videoQuality error:&error];
            
        } else {
            return [self->task error:[NSString stringWithFormat:@"Unsupported media type: %@", type] type:@"UNEXPECTED_FAILURE" subtype:nil];
        }

        if (error != nil) {
            return [self->task error:[NSString stringWithFormat:@"Error saving media: %@", error.localizedDescription] type:@"UNEXPECTED_FAILURE" subtype:nil];
        }

        if (selectionLimit == 1) {
            [self->task success:[forgeFile toScriptObject]];
        } else {
            [self->task success:@[
                [forgeFile toScriptObject]
            ]];
        }
    }];
}


#pragma mark helpers

- (ForgeFile*)saveVideoForInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info videoQuality:(NSString*)videoQuality error:(NSError**)error {
    NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];
    if (url == nil) {
        *error = [NSError errorWithDomain:ForgeErrorDomain
                                     code:ForgeErrorCode
                                 userInfo:@{
             NSLocalizedDescriptionKey:@"Failed to obtain url for the selected item"
         }];
        return nil;
    }
    
    return [file_Storage writeNSURLToTemporaryFile:url error:error];
}

@end
