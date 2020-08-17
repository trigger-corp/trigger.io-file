//
//  file_PHPickerViewControllerDelegate.h
//  ForgeModule
//
//  Created by Antoine van Gelder on 2020/08/13.
//  Copyright © 2020 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PhotosUI/PHPicker.h>

#import <ForgeCore/ForgeTask.h>


NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(14))
@interface file_PHPickerDelegate : NSObject <PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate> {
    file_PHPickerDelegate *me;
    ForgeTask *task;
    PHPickerConfiguration *configuration;
}

+ (file_PHPickerDelegate*) withTask:(ForgeTask*)task andConfiguration:(PHPickerConfiguration*)configuration API_AVAILABLE(ios(14));

- (void)openPicker;

@end

NS_ASSUME_NONNULL_END
