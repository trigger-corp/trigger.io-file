//
//  file_API.h
//  Forge
//
//  Copyright (c) 2020 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface file_API : NSObject

+ (void)getImage:(ForgeTask*)task;
+ (void)getVideo:(ForgeTask*)task;

+ (void)getFileFromSourceDirectory:(ForgeTask*)task resource:(NSString*)resource;
+ (void)getURLFromSourceDirectory:(ForgeTask*)task resource:(NSString*)resource;

+ (void)getScriptPath:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)getScriptURL:(ForgeTask*)task file:(NSDictionary*)file;

+ (void)isFile:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)info:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)base64:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)string:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)remove:(ForgeTask*)task file:(NSDictionary*)file;

+ (void)cacheURL:(ForgeTask*)task url:(NSString*)url;
+ (void)saveURL:(ForgeTask*)task url:(NSString*)url;

+ (void)clearCache:(ForgeTask*)task;
+ (void)getStorageSizeInformation:(ForgeTask*)task;

@end
