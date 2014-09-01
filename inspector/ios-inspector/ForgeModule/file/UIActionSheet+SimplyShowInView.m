//
//  UIActionSheet+SimplyShowInView.m
//  ForgeModule
//
//  Created by Antoine van Gelder on 9/1/14.
//  Copyright (c) 2014 Trigger Corp. All rights reserved.
//

#import "UIActionSheet+SimplyShowInView.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@implementation UIActionSheet (simplyShowInView)

- (void) simplyShowInView:(UIView *) view
{
    if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {
        [self showInView:view];
        
    } else {
        // "Translating" UIActionSheet to UIAlertController for better compatibility with iOS 8
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:self.title preferredStyle:UIAlertControllerStyleActionSheet];
        long nactions = [self numberOfButtons];
        for (long i = 0; i < nactions; i++) {
            NSString *button_title = [self buttonTitleAtIndex:i];
            UIAlertActionStyle style = UIAlertActionStyleDefault;
            if (i == [self cancelButtonIndex]) {
                style = UIAlertActionStyleCancel;
            } else if (i==[self destructiveButtonIndex]) {
                style = UIAlertActionStyleDestructive;
            }
            
            UIAlertAction *newAction = [UIAlertAction actionWithTitle:button_title style:style handler:^(UIAlertAction *action) {
                [self.delegate actionSheet:self didDismissWithButtonIndex:i];
            }];
            
            [alert addAction:newAction];
        }
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [alert setModalPresentationStyle:UIModalPresentationPopover];
            
            UIPopoverPresentationController *popPresenter = [alert popoverPresentationController];
            popPresenter.sourceView = view;
            popPresenter.sourceRect = CGRectMake(view.frame.size.width / 2 - 1, 0.45 * view.frame.size.height, 2, 1);
            popPresenter.permittedArrowDirections = 0;
        }
        UIViewController *sourceViewController;
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(presentViewController:animated:completion:)]) {
            sourceViewController = (UIViewController *)(self.delegate);
        } else {
            sourceViewController = [[ForgeApp sharedApp] viewController];        }
        [sourceViewController presentViewController:alert animated:YES completion:nil];
    }
}

@end
