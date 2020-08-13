//
//  file_PHPickerViewControllerDelegate.h
//  ForgeModule
//
//  Created by Antoine van Gelder on 2020/08/13.
//  Copyright © 2020 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PhotosUI/PHPicker.h>

NS_ASSUME_NONNULL_BEGIN

@interface file_PHPickerDelegate : NSObject <PHPickerViewControllerDelegate> 

- (void)openPicker API_AVAILABLE(ios(14));
- (void)closePicker:(void (^ __nullable)(void))success;

@end

NS_ASSUME_NONNULL_END
