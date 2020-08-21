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
            NSDictionary *file = nil;
            if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
                file = [self saveImageForResultSync:result error:&error];
            } else if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeQuickTimeMovie.identifier]) {
                file = [self saveVideoForResultSync:result error:&error];
            }

            if (error != nil) {
                *stop = true;
                return;
            }

            // TODO also return result.assetIdentifier as part of the file object
            if (file != nil) {
                [ret addObject:file];
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

- (NSDictionary*)saveImageForResultSync:(PHPickerResult*)result error:(NSError**)error {
    if (![result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        *error = [NSError errorWithDomain:NSItemProviderErrorDomain
                                    code:NSItemProviderUnavailableCoercionError
                                userInfo:@{
            NSLocalizedDescriptionKey:@"Cannot load image data for the selected item"
        }];
        return nil;
    }

    __block NSDictionary *ret = nil;
    __block NSError *error_ret = nil; // avoid capturing loadObjectOfClass's NSError

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); { // perform operation synchronously

        // TODO handle live photos

        [result.itemProvider loadObjectOfClass:([UIImage class]) completionHandler:^(UIImage* image, NSError* error) {
            if (error != nil) {
                error_ret = error;

            } else {
                NSString *filename = [ForgeStorage temporaryFileNameWithExtension:@"jpg"];
                NSURL *url = [ForgeStorage.temporaryDirectory URLByAppendingPathComponent:filename];

                [UIImageJPEGRepresentation(image, 0.9) writeToURL:url atomically:YES];
                [[NSFileManager defaultManager] addSkipBackupAttributeToItemAtURL:url];

                ret = @{
                    @"mimetype": @"image/jpg",
                    @"route": ForgeStorage.temporaryRoute,
                    @"filename": filename,
                    @"path": [ForgeStorage.temporaryRoute stringByAppendingPathComponent:filename],

                    @"_url": url.absoluteString,
                    @"_ios_assetIdentifier": result.assetIdentifier,
                    @"_uri": url.path,  // TODO deprecate - for backwards compatibility < iOS 14
                };
            }
            dispatch_semaphore_signal(semaphore);
        }];
    } dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    *error = error_ret;
    return ret;
}


- (NSDictionary*)saveVideoForResultSync:(PHPickerResult*)result error:(NSError**)error {
    __block NSDictionary *ret = nil;
    __block NSError *error_ret = nil; // avoid capturing loadObjectOfClass's NSError

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); { // perform operation synchronously
        [result.itemProvider loadFileRepresentationForTypeIdentifier:UTTypeQuickTimeMovie.identifier completionHandler:^(NSURL* _Nullable result_url, NSError * _Nullable error) {
            if (error != nil) {
                error_ret = error;

            } else {
                NSString *extension = result_url.pathExtension;
                if (extension == nil) {
                    extension = @"mp4";
                }
                NSString *filename = [ForgeStorage temporaryFileNameWithExtension:extension];
                NSURL *url = [ForgeStorage.temporaryDirectory URLByAppendingPathComponent:filename];

                NSData *data = [NSData dataWithContentsOfURL:result_url];
                if (data == nil) {
                    error_ret = [NSError errorWithDomain:NSItemProviderErrorDomain
                                                code:NSItemProviderUnavailableCoercionError
                                            userInfo:@{
                        NSLocalizedDescriptionKey:@"Failed to load image data for the selected item"
                    }];

                } else if (![data writeToURL:url atomically:YES]) {
                    error_ret = [NSError errorWithDomain:NSItemProviderErrorDomain
                                                code:NSItemProviderUnavailableCoercionError
                                            userInfo:@{
                        NSLocalizedDescriptionKey:@"Failed to write image data for the selected item"
                    }];

                } else {
                    [[NSFileManager defaultManager] addSkipBackupAttributeToItemAtURL:url];
                    ret = @{
                        @"mimetype": [NSString stringWithFormat:@"video/%@", extension],
                        @"route": ForgeStorage.temporaryRoute,
                        @"filename": filename,
                        @"path": [ForgeStorage.temporaryRoute stringByAppendingPathComponent:filename],

                        @"_url": url.absoluteString,
                        @"_ios_assetIdentifier": result.assetIdentifier,
                        @"_uri": url.path,  // TODO deprecate - for backwards compatibility < iOS 14
                    };
                }
            }
            dispatch_semaphore_signal(semaphore);
        }];
    } dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    *error = error_ret;
    return ret;
}

@end
