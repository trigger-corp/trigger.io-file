//
//  file_PHPickerViewControllerDelegate.m
//  ForgeModule
//
//  Created by Antoine van Gelder on 2020/08/13.
//  Copyright © 2020 Trigger Corp. All rights reserved.
//

#import "file_PHPickerDelegate.h"

#import <Photos/Photos.h>


@implementation file_PHPickerDelegate

#pragma mark life-cycle

+ (file_PHPickerDelegate*) withTask:(ForgeTask*)initTask filter:(PHPickerFilter*)filter {
    file_PHPickerDelegate *delegate = [[self alloc] init];
    if (delegate) {
        delegate->me = delegate; // "retain"
    }
    
    return delegate;
}

#pragma mark methods


- (void)openPicker { //API_AVAILABLE(ios(14)) {
    //PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
    config.selectionLimit = 1; // TODO support selectionLimit if we can do the same on Android
    config.filter = [PHPickerFilter imagesFilter]; // TODO get from class property

    PHPickerViewController *controller = [[PHPickerViewController alloc] initWithConfiguration:config];
    controller.delegate = self;
    [[[ForgeApp sharedApp] viewController] presentViewController:controller animated:YES completion:nil];
}


- (void)closePicker:(void (^ __nullable)(void))success {
    [[[ForgeApp sharedApp] viewController] dismissViewControllerAnimated:YES completion:^{
        if (success != nil) success();
    }];
}


#pragma mark callbacks

-(void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)){
    
    // TODO didReturn = YES;
    [picker dismissViewControllerAnimated:YES completion:^{
        // TODO can obj-c do: results.compactMap(\.assetIdentifier
        for (PHPickerResult *result in results) {
            /*[result.itemProvider loadObjectOfClass:[UIImage class]
                                 completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
                if ([object isKindOfClass:[UIImage class]]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"Selected image: %@", (UIImage*)object);
                    });
                }
            }];*/
            NSLog(@"Selected image: %@", result.assetIdentifier);
            if (result.assetIdentifier != nil) {
                PHFetchResult<PHAsset *> *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[result.assetIdentifier] options:nil];
                PHAsset *asset = nil;
                if ([fetchResult count] >= 1) {
                    asset = [fetchResult firstObject];
                }
                NSLog(@"Selected asset: %@", asset);
            }
        }
    }];
}

@end
