//
//  file_Util.h
//  ForgeModule
//
//  Created by Antoine van Gelder on 2017/11/28.
//  Copyright © 2017 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>


@interface file_Storage : NSObject

+ (ForgeFile*)writeUIImageToTemporaryFile:(UIImage*)image maxWidth:(int)maxWidth maxHeight:(int)maxHeight error:(NSError**)error;
+ (ForgeFile*)writeNSURLToTemporaryFile:(NSURL*)url error:(NSError**)error;

+ (void)transcode:(PHAsset*)asset withTask:(ForgeTask*)task videoQuality:(NSString*)videoQuality;

@end
