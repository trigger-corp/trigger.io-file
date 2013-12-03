//
//  file_PictureTakerDelegate.h
//  ForgeModule
//
//  Created by Connor Dunn on 19/03/2013.
//  Copyright (c) 2013 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

@interface file_PictureTakerDelegate : NSObject {
	ForgeTask *task;
	file_PictureTakerDelegate *me;
}

- (file_PictureTakerDelegate*) initWithTask:(ForgeTask*)initTask;
- (void)pictureTakerDidEnd:(IKPictureTaker *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end
