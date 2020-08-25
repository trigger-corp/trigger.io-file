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
    file_Delegate_deprecated *me;
	ForgeTask *task;
    NSString* type;
    	
	UIImagePickerController *keepPicker;
}

+ (file_Delegate_deprecated*) withTask:(ForgeTask*)task type:(NSString*)type;

- (void)openPicker;
    
@end
