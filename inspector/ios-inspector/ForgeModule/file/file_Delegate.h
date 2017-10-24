//
//  file_Delegate.h
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface file_Delegate : NSObject <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
	ForgeTask *task;
	file_Delegate *me;
	UIPopoverController *keepPopover;
	UIImagePickerController *keepPicker;
	id params;
	BOOL didReturn;
	NSString* type;
}

- (file_Delegate*_Nullable) initWithTask:(ForgeTask*_Nullable)initTask andParams:(id _Nullable )initParams andType:(NSString*_Nullable)initType;
- (void)closePicker:(void (^ __nullable)(void))success;
- (void)cancel;
- (void)didDisappear;

@end
