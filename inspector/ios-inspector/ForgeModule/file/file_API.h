//
//  file_API.h
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface file_API : NSObject

+ (void)getImage:(ForgeTask*)task /*source:(NSString*)source*/;
+ (void)getVideo:(ForgeTask*)task /*source:(NSString*)source*/;

+ (void)getLocal:(ForgeTask*)task name:(NSString*)path; // TODO deprecate in favour of getLocalWithRoute ?

+ (void)URL:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)isFile:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)info:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)base64:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)string:(ForgeTask*)task file:(NSDictionary*)file;
+ (void)cacheURL:(ForgeTask*)task url:(NSString*)url;
+ (void)remove:(ForgeTask*)task file:(NSDictionary*)file;

+ (void)clearCache:(ForgeTask*)task;
+ (void)getStorageInformation:(ForgeTask*)task;

@end
