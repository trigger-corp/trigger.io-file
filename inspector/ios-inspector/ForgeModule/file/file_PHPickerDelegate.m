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

#import "file_Storage.h"
#import "file_PHPickerDelegate.h"


@implementation file_PHPickerDelegate

#pragma mark life-cycle

+ (file_PHPickerDelegate*) withTask:(ForgeTask*)task configuration:(PHPickerConfiguration*)configuration {
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
    int width = task.params[@"width"] ? [task.params[@"width"] intValue] : 0;
    int height = task.params[@"height"] ? [task.params[@"height"] intValue] : 0;
    NSString *videoQuality = task.params[@"videoQuality"] ? (NSString*)task.params[@"videoQuality"] : @"default";
    
    [picker dismissViewControllerAnimated:YES completion:^{
        if (results.count == 0) {
            [self->task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
            return;
        }

        NSMutableArray<ForgeFile*> *files = [NSMutableArray arrayWithCapacity:results.count];
        __block bool exitEarly = false; // TODO transcoded videos have an akward path
        __block NSError *error = nil;

        [results enumerateObjectsUsingBlock:^(PHPickerResult *result, NSUInteger index, BOOL *stop) {
            ForgeFile *file = nil;
            if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
                file = [self saveImageForResultSync:result maxWidth:width maxHeight:height error:&error];
                
            } else if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
                if (![videoQuality isEqualToString:@"default"]) {
                    // TODO until Apple allow us to transcode PHPicker results directly
                    NSString *assetIdentifier = result.assetIdentifier;
                    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];
                    if (fetchResult.count == 0) {
                        return;
                    }
                    PHAsset *asset = fetchResult.firstObject;
                    [file_Storage transcode:asset withTask:self->task videoQuality:videoQuality];
                    *stop = true;
                    exitEarly = true;
                    return;
                }
                file = [self saveVideoForResultSync:result videoQuality:videoQuality error:&error];
            }

            if (error != nil) {
                *stop = true;
                return;
            }

            if (file != nil) {
                [files addObject:file];
            }
        }];
        
        if (exitEarly) {
            // TODO result was handled by [file_Storage transcode]
        } else if (error != nil) {
            [self->task error:[error localizedDescription] type:@"UNEXPECTED_FAILURE" subtype:nil];
        } else if (files.count == 0) {
            [self->task error:@"No valid items selected" type:@"UNEXPECTED_FAILURE" subtype:nil];
        } else if (picker.configuration.selectionLimit == 1) {
            [self->task success:[files.firstObject toScriptObject]];
        } else {
            NSMutableArray *scriptObjects = [NSMutableArray new];
            [files enumerateObjectsUsingBlock:^(ForgeFile *file, NSUInteger idx, BOOL *stop) {
                [scriptObjects addObject:[file toScriptObject]];
            }];
            [self->task success:scriptObjects];
        }

        self->me = nil;
    }];
}


#pragma mark helpers

- (ForgeFile*)saveImageForResultSync:(PHPickerResult*)result maxWidth:(int)maxWidth maxHeight:(int)maxHeight error:(NSError**)error {
    if (![result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        *error = [NSError errorWithDomain:NSItemProviderErrorDomain
                                    code:NSItemProviderUnavailableCoercionError
                                userInfo:@{
            NSLocalizedDescriptionKey:@"Cannot load image data for the selected item"
        }];
        return nil;
    }

    __block ForgeFile *ret = nil;
    __block NSError *error_ret = nil; // avoid capturing loadObjectOfClass's NSError

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); { // perform operation synchronously
        [result.itemProvider loadObjectOfClass:([UIImage class]) completionHandler:^(UIImage* image, NSError* error) {
            if (error != nil) {
                error_ret = error;

            } else {
                ret = [file_Storage writeUIImageToTemporaryFile:image maxWidth:maxWidth maxHeight:maxHeight error:&error_ret];
            }
            dispatch_semaphore_signal(semaphore);
        }];
    } dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    *error = error_ret;
    return ret;
}


- (ForgeFile*)saveVideoForResultSync:(PHPickerResult*)result videoQuality:(NSString*)videoQuality error:(NSError**)error {
    __block ForgeFile *ret = nil;
    __block NSError *error_ret = nil; // avoid capturing loadObjectOfClass's NSError

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0); { // perform operation synchronously
        
        // TODO handle live photos

        [result.itemProvider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier completionHandler:^(NSURL* _Nullable url, NSError * _Nullable error) {
            if (error != nil) {
                error_ret = error;

            } else {
                ret = [file_Storage writeNSURLToTemporaryFile:url error:&error_ret];
            }
            dispatch_semaphore_signal(semaphore);
        }];
    } dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    *error = error_ret;
    return ret;
}

@end
