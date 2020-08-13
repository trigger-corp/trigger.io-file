//
//  file_PHPickerViewControllerDelegate.m
//  ForgeModule
//
//  Created by Antoine van Gelder on 2020/08/13.
//  Copyright © 2020 Trigger Corp. All rights reserved.
//

#import "file_PHPickerDelegate.h"

@implementation file_PHPickerDelegate

#pragma mark life-cycle


#pragma mark methods


- (void)openPicker { //API_AVAILABLE(ios(14)) {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 3;
    config.filter = [PHPickerFilter imagesFilter];

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
        for (PHPickerResult *result in results) {
            [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error)
             {
                if ([object isKindOfClass:[UIImage class]])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"Selected image: %@", (UIImage*)object);
                    });
                }
            }];
        }
        
    }];
    
}

@end
