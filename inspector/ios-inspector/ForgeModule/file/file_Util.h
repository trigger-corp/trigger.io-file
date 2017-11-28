//
//  file_Util.h
//  ForgeModule
//
//  Created by Antoine van Gelder on 2017/11/28.
//  Copyright © 2017 Trigger Corp. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>


@interface file_Util : NSObject

+ (void)transcode:(PHAsset*)asset withTask:(ForgeTask*)task videoQuality:(NSString*)videoQuality;

@end
