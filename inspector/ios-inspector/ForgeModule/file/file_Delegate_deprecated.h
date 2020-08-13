//
//  file_Delegate.h
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface file_Delegate_deprecated : NSObject <UINavigationControllerDelegate,
                                     UIImagePickerControllerDelegate>
{
	ForgeTask *task;
	file_Delegate_deprecated *me;
	UIImagePickerController *keepPicker;
	id params;
	BOOL didReturn;
	NSString* type;
}

- (file_Delegate_deprecated*_Nullable) initWithTask:(ForgeTask*_Nullable)initTask andParams:(id _Nullable )initParams andType:(NSString*_Nullable)initType;
- (void)openPicker;
- (void)closePicker:(void (^ __nullable)(void))success;
- (void)cancel;
- (void)didDisappear;

@end
