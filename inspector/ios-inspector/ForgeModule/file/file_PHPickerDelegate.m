//
//  file_PHPickerViewControllerDelegate.m
//  ForgeModule
//
//  Created by Antoine van Gelder on 2020/08/13.
//  Copyright © 2020 Trigger Corp. All rights reserved.
//

#import <UniformTypeIdentifiers/UTCoreTypes.h>
#import <Photos/Photos.h>

#import <ForgeCore/ForgeStorage.h>
#import <ForgeCore/NSString+Hex.h>

#import "file_PHPickerDelegate.h"


@implementation file_PHPickerDelegate

#pragma mark life-cycle

+ (file_PHPickerDelegate*) withTask:(ForgeTask*)task andConfiguration:(PHPickerConfiguration*)configuration {
    file_PHPickerDelegate *delegate = [[self alloc] init];
    if (delegate) {
        delegate->me = delegate; // "retain"
        delegate->task = task;
        delegate->configuration = configuration;
    }

    return delegate;
}


#pragma mark interface

- (void) openPicker {
    PHPickerViewController *controller = [[PHPickerViewController alloc] initWithConfiguration:self->configuration];
    controller.delegate = self;
    controller.presentationController.delegate = self;

    [[[ForgeApp sharedApp] viewController] presentViewController:controller animated:YES completion:nil];
}


#pragma mark callbacks

- (void) presentationControllerWillDismiss:(UIPresentationController*)presentationController {
    [task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
    self->me = nil;
}


- (void) picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:^{
        if (results.count == 0) {
            [self->task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
            return;
        }

        NSMutableArray *ret = [NSMutableArray arrayWithCapacity:results.count];
        __block NSError *error = nil;

        [results enumerateObjectsUsingBlock:^(PHPickerResult *result, NSUInteger index, BOOL *stop) {
            NSURL *url = nil;
            if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
                url = [self saveImageForResultSync:result error:&error];
            } else if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeQuickTimeMovie.identifier]) {
                url = [self saveVideoForResultSync:result error:&error];
            }

            if (error != nil) {
                *stop = true;
                return;
            }
            
            // TODO also return result.assetIdentifier as part of the file object
            if (url != nil) {
                [ret addObject:[url path]];
            }
        }];

        if (error != nil) {
            [self->task error:[error localizedDescription] type:@"UNEXPECTED_FAILURE" subtype:nil];
        } else if (ret.count == 0) {
            [self->task error:@"No valid items selected" type:@"UNEXPECTED_FAILURE" subtype:nil];
        } else {
            [self->task success:ret.firstObject];
        }

        self->me = nil;
    }];
}


#pragma mark helpers

- (NSURL*)saveImageForResultSync:(PHPickerResult*)result error:(NSError**)error {
    if (![result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        *error = [NSError errorWithDomain:NSItemProviderErrorDomain
                                    code:NSItemProviderUnavailableCoercionError
                                userInfo:@{
            NSLocalizedDescriptionKey:@"Cannot load image data for the selected item"
        }];
        return nil;
    }

    __block NSURL *ret = nil;
    __block NSError *error_ret = nil; // avoid capturing loadObjectOfClass's NSError

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); { // perform operation synchronously
        
        // TODO handle live photos
        
        [result.itemProvider loadObjectOfClass:([UIImage class]) completionHandler:^(UIImage* image, NSError* error) {
            if (error != nil) {
                error_ret = error;

            } else {
                // TODO move tempfile creation code to ForgeStorage
                NSString *path = ForgeStorage.temporaryDirectory.path;
                NSString *uuid = [[NSUUID UUID] UUIDString];
                NSString *filename = [NSString stringWithFormat:@"%@.%@", uuid, @"png"];
                path = [path stringByAppendingPathComponent:filename];

                [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
                [[NSFileManager defaultManager] addSkipBackupAttributeToItemAtPath:path];

                // path =  [@"/tmp" stringByAppendingPathComponent:filename]; // TODO support /tmp paths in ForgeFile
                ret = [NSURL fileURLWithPath:path relativeToURL:nil];
            }

            dispatch_semaphore_signal(semaphore);
        }];
    } dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    *error = error_ret;
    return ret;
}


- (NSURL*)saveVideoForResultSync:(PHPickerResult*)result error:(NSError**)error {
    __block NSURL *ret = nil;
    __block NSError *error_ret = nil; // avoid capturing loadObjectOfClass's NSError

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); { // perform operation synchronously
        [result.itemProvider loadFileRepresentationForTypeIdentifier:UTTypeQuickTimeMovie.identifier completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
            if (error != nil) {
                error_ret = error;

            } else {
                // TODO move tempfile creation code to ForgeStorage
                NSString *path = ForgeStorage.temporaryDirectory.path;
                NSString *uuid = [[NSUUID UUID] UUIDString];
                NSString *filename = [NSString stringWithFormat:@"%@.%@", uuid, @"mp4"];
                path = [path stringByAppendingPathComponent:filename];

                NSData *data = [NSData dataWithContentsOfURL:url];
                if (data == nil) {
                    error_ret = [NSError errorWithDomain:NSItemProviderErrorDomain
                                                code:NSItemProviderUnavailableCoercionError
                                            userInfo:@{
                        NSLocalizedDescriptionKey:@"Failed to load image data for the selected item"
                    }];

                } else if (![data writeToFile:path atomically:YES]) {
                    error_ret = [NSError errorWithDomain:NSItemProviderErrorDomain
                                                code:NSItemProviderUnavailableCoercionError
                                            userInfo:@{
                        NSLocalizedDescriptionKey:@"Failed to write image data for the selected item"
                    }];

                } else {
                    [[NSFileManager defaultManager] addSkipBackupAttributeToItemAtPath:path];
                    path =  [@"/tmp" stringByAppendingPathComponent:filename]; // TODO support /tmp paths in ForgeFile
                    ret = [NSURL fileURLWithPath:path relativeToURL:nil];
                }
            }
            dispatch_semaphore_signal(semaphore);
        }];
    } dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    *error = error_ret;
    return ret;
}

@end
