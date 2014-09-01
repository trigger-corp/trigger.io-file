//
//  UIActionSheet+SimplyShowInView.h
//  ForgeModule
//
//  Created by Antoine van Gelder on 9/1/14.
//  Copyright (c) 2014 Trigger Corp. All rights reserved.
//


/**
 * Workaround for crashing UIActionSheets on iPad running iOS 8
 *
 * From: https://devforums.apple.com/message/1030406#1030406
 *       http://stackoverflow.com/questions/24363761/uiactionsheet-crash-in-ios8beta
 *
 * TODO: Check against iOS8 final
 */
@interface UIActionSheet (simplyShowInView)
- (void) simplyShowInView:(UIView *) view;
@end
