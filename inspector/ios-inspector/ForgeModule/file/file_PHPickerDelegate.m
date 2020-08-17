//
//  file_PHPickerViewControllerDelegate.m
//  ForgeModule
//
//  Created by Antoine van Gelder on 2020/08/13.
//  Copyright © 2020 Trigger Corp. All rights reserved.
//

#import <UniformTypeIdentifiers/UTCoreTypes.h>
#import <Photos/Photos.h>
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

#pragma mark methods


- (void) openPicker { //API_AVAILABLE(ios(14)) {
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


- (NSURL*)saveImageForResultSync:(PHPickerResult*)result error:(NSError**)error {
    if (![result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        *error = [NSError errorWithDomain:NSItemProviderErrorDomain
                                    code:NSItemProviderUnavailableCoercionError
                                userInfo:@{
            NSLocalizedDescriptionKey:@"Cannot load image data for the selected object"
        }];
        return nil;
    }

    __block NSURL *ret = nil;
    __block NSError *error_tmp = nil; // avoid capturing loadObjectOfClass's NSError

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);  { // perform operation synchronously
        [result.itemProvider loadObjectOfClass:([UIImage class]) completionHandler:^(UIImage* image, NSError* error) {
            if (error != nil) {
                error_tmp = error;
                dispatch_semaphore_signal(semaphore);
                return;
            }
            NSString *path = NSTemporaryDirectory();
            NSString *uuid = [[NSUUID UUID] UUIDString];
            NSString *filename = [NSString stringWithFormat:@"%@.%@", uuid, @"png"];
            path = [path stringByAppendingPathComponent:filename];
            [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
            ret = [NSURL fileURLWithPath:path relativeToURL:nil];
            dispatch_semaphore_signal(semaphore);
        }];
    } dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    *error = error_tmp;
    return ret;
}


- (void) picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    /*[picker dismissViewControllerAnimated:YES completion:^{
        // TODO can obj-c do: results.compactMap(\.assetIdentifier
        for (PHPickerResult *result in results) {
            NSLog(@"Selected image: %@", result.assetIdentifier);
            if (result.assetIdentifier != nil) {
                PHFetchResult<PHAsset*> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[result.assetIdentifier] options:nil];
                PHAsset *asset = nil;
                if ([fetchResult count] == 0) {
                    // handle error
                    return;
                }
                asset = [fetchResult firstObject];
                NSString *ret = [NSString stringWithFormat:@"photo-library://image/%@?ext=JPG", [asset localIdentifier]];
                NSLog(@"Selected asset: %@ -> %@", asset, ret);
            }
        }
    }];*/

    [picker dismissViewControllerAnimated:YES completion:^{
        if (results.count == 0) {
            [self->task error:@"Image selection cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
            return;
        }

        NSMutableArray *ret = [NSMutableArray arrayWithCapacity:results.count];
        __block NSError *error = nil;

        [results enumerateObjectsUsingBlock:^(PHPickerResult *result, NSUInteger index, BOOL *stop) {
            // TODO return this as part of the file object
            //NSString *assetIdentifier = [result.assetIdentifier stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
            //NSString *assetIdentifier = [NSString stringToHex:result.assetIdentifier];

            if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
                NSURL *url = [self saveImageForResultSync:result error:&error];
                if (error != nil) {
                    *stop = true;
                    return;
                }
                [ret addObject:[url absoluteString]];

            } else if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeAudiovisualContent.identifier]) {
                NSLog(@"Video");
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

// how to handle returned data
// https://developer.apple.com/documentation/foundation/nsitemprovider?language=objc
// also try: loadFileRepresentationForTypeIdentifier, loadInPlaceFileRepresentationForTypeIdentifier


// how to handle video: https://medium.com/dev-genius/the-new-photos-picker-in-ios-14-part-2-f4864b5df837
// also see: https://github.com/aarsh518/PHPickerViewDemo
//           https://stackoverflow.com/questions/63397033/

@end
