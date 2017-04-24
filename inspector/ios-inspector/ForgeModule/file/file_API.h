//
//  file_API.h
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface file_API : NSObject

+ (void)getImage:(ForgeTask*)task source:(NSString*)source;
+ (void)getVideo:(ForgeTask*)task source:(NSString*)source;
+ (void)getLocal:(ForgeTask*)task name:(NSString*)name;
+ (void)URL:(ForgeTask*)task;
+ (void)isFile:(ForgeTask*)task;
+ (void)info:(ForgeTask*)task;
+ (void)base64:(ForgeTask*)task;
+ (void)string:(ForgeTask*)task;
+ (void)cacheURL:(ForgeTask*)task url:(NSString*)url;
+ (void)remove:(ForgeTask*)task;
+ (void)clearCache:(ForgeTask*)task;
+ (void)getStorageInformation:(ForgeTask*)task;

+ (NSNumber*)getDirectorySize:(NSString *)path;

@end

extern NSString *io_trigger_dialog_capture_camera_description;
extern NSString *io_trigger_dialog_capture_source_camera;
extern NSString *io_trigger_dialog_capture_source_gallery;
extern NSString *io_trigger_dialog_capture_pick_source;
extern NSString *io_trigger_dialog_cancel;



