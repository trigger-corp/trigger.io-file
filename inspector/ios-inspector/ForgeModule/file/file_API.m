//
//  file_API.m
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import <CoreServices/UTCoreTypes.h>

#import <Photos/Photos.h>
#import <PhotosUI/PHPicker.h>

#import "JLPhotosPermission.h"

#import "file_API.h"
#import "file_PHPickerDelegate.h"
#import "file_Delegate_deprecated.h"


@implementation file_API

+ (void)getImage:(ForgeTask*)task source:(NSString*)source {
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
        configuration.selectionLimit = 1;
        configuration.filter = PHPickerFilter.imagesFilter;
        file_PHPickerDelegate *delegate = [file_PHPickerDelegate withTask:task andConfiguration:configuration];
        [delegate openPicker];
    } else {
        file_Delegate_deprecated *delegate = [[file_Delegate_deprecated alloc] initWithTask:task andParams:task.params andType:(NSString *)kUTTypeImage];
        [delegate openPicker];
    }
}

+ (void)getVideo:(ForgeTask*)task source:(NSString*)source {
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
        configuration.selectionLimit = 1;
        configuration.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
            PHPickerFilter.videosFilter,
            // TODO PHPickerFilter.livePhotosFilter 
        ]];
        file_PHPickerDelegate *delegate = [file_PHPickerDelegate withTask:task andConfiguration:configuration];
        [delegate openPicker];
    } else {
        file_Delegate_deprecated *delegate = [[file_Delegate_deprecated alloc] initWithTask:task andParams:task.params andType:(NSString *)kUTTypeMovie];
        [delegate openPicker];
    }
}

+ (void)getLocal:(ForgeTask*)task name:(NSString*)name {
    [task success:[[[ForgeFile alloc] initWithPath:name] toJSON]];
}

+ (void)URL:(ForgeTask*)task {
    [task success:[[[ForgeFile alloc] initWithFile:task.params] url]];
}

+ (void)isFile:(ForgeTask*)task {
    if (![task.params objectForKey:@"uri"] || [task.params objectForKey:@"uri"] == [NSNull null]) {
        [task success:[NSNumber numberWithBool:NO]];
    } else {
        [[[ForgeFile alloc] initWithFile:task.params] exists:^(BOOL exists) {
            [task success:[NSNumber numberWithBool:exists]];
        }];
    }
}

+ (void)info:(ForgeTask*)task {
    if (![task.params objectForKey:@"uri"] || [task.params objectForKey:@"uri"] == [NSNull null]) {
        [task error:@"Invalid parameters sent to file.size" type:@"BAD_INPUT" subtype:nil];
        return;
    }

    [[[ForgeFile alloc] initWithFile:task.params] info:^(NSDictionary *info) {
        [task success:info];
    } errorBlock:^(NSString *description) {
        [task error:description type:@"UNEXPECTED_FAILURE" subtype:nil];
    }];
}

+ (void)base64:(ForgeTask*)task {
    if (![task.params objectForKey:@"uri"] || [task.params objectForKey:@"uri"] == [NSNull null]) {
        [task error:@"Invalid parameters sent to file.base64" type:@"BAD_INPUT" subtype:nil];
    }
    [[[ForgeFile alloc] initWithFile:task.params] data:^(NSData *data) {
        [task success:[data base64EncodingWithLineLength:0]];
    } errorBlock:^(NSError *error) {
        [task error:[error localizedDescription] type:@"EXPECTED_FAILURE" subtype:nil];
    }];
}

+ (void)string:(ForgeTask*)task {
    if (![task.params objectForKey:@"uri"] || [task.params objectForKey:@"uri"] == [NSNull null]) {
        [task error:@"Invalid parameters sent to file.base64" type:@"BAD_INPUT" subtype:nil];
    }
    [[[ForgeFile alloc] initWithFile:task.params] data:^(NSData *data) {
        [task success:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    } errorBlock:^(NSError *error) {
        [task error:[error localizedDescription] type:@"EXPECTED_FAILURE" subtype:nil];
    }];
}

+ (void)cacheURL:(ForgeTask*)task url:(NSString*)url {
    NSString *uuid = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, CFUUIDCreate(NULL));
    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[uuid stringByAppendingString:[[[[NSURL URLWithString:url] path] pathComponents] lastObject]]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];

        if ([data writeToFile:tempFile atomically:YES]) {
            [[NSFileManager defaultManager] addSkipBackupAttributeToItemAtPath:tempFile];
            [task success:tempFile];
        } else {
            [task error:@"Unable to save to file" type:@"UNEXPECTED_FAILURE" subtype:nil];
        }
    });
}

+ (void)saveURL:(ForgeTask*)task url:(NSString*)url {
    // TODO move tempfile creation code to ForgeStorage
    NSString *uuid = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, CFUUIDCreate(NULL));
    NSString *tempFile = [[ForgeApp.sharedApp.applicationSupportDirectory.path stringByAppendingPathComponent:uuid] stringByAppendingString:[[[[NSURL URLWithString:url] path] pathComponents] lastObject]];

    // TODO any reason why we're using the global queue?
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];

        if ([data writeToFile:tempFile atomically:YES]) {
            [[NSFileManager defaultManager] addSkipBackupAttributeToItemAtPath:tempFile];
            [task success:tempFile];
        } else {
            [task error:@"Unable to save to file" type:@"UNEXPECTED_FAILURE" subtype:nil];
        }
    });
}

+ (void)remove:(ForgeTask*)task {
    // We can only delete files not URIs
    if ([[task.params objectForKey:@"uri"] hasPrefix:@"/"]) {
        if ([[NSFileManager defaultManager] removeItemAtPath:[task.params objectForKey:@"uri"] error:nil]) {
            [task success:nil];
        } else {
            [task error:@"Unable to delete file" type:@"UNEXPECTED_ERROR" subtype:nil];
        }
    } else {
        [task error:@"Not a deletable file" type:@"BAD_INPUT" subtype:nil];
    }
}

+ (void)clearCache:(ForgeTask*)task {
    for (NSString *path in [[NSFileManager defaultManager] subpathsAtPath:NSTemporaryDirectory()]) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:path] error:nil];
    }
    [task success:nil];
}

+ (void)getStorageInformation:(ForgeTask*)task {
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    NSString* appDir = [[NSBundle mainBundle] bundlePath];
    NSString* cacheDir = NSTemporaryDirectory();

    if (!dictionary || !cacheDir || !appDir) {
        [task error:@"Error reading storage information" type:@"UNEXPECTED_FAILURE" subtype:nil];
        return;
    }

    [task success:@{@"total": [dictionary objectForKey: NSFileSystemSize],
                    @"free": [dictionary objectForKey:NSFileSystemFreeSize],
                    @"app": [file_API getDirectorySize:appDir],
                    @"cache": [file_API getDirectorySize:cacheDir]}];
}

+ (NSNumber*)getDirectorySize:(NSString *)path {
    unsigned long long int result = 0;

    NSArray *files = [[NSFileManager defaultManager] subpathsAtPath:path];

    for (NSString *file in files) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:file] error:nil];
        result += [attrs fileSize];
    }

    return [NSNumber numberWithUnsignedLongLong:result];
}


+ (void)permissions_check:(ForgeTask*)task permission:(NSString *)permission {
    JLPermissionsCore* jlpermission = [JLPhotosPermission sharedInstance];
    JLAuthorizationStatus status = [jlpermission authorizationStatus];
    [task success:[NSNumber numberWithBool:status == JLPermissionAuthorized]];
}


+ (void)permissions_request:(ForgeTask*)task permission:(NSString *)permission {
    JLPermissionsCore* jlpermission = [JLPhotosPermission sharedInstance];
    if ([jlpermission authorizationStatus] == JLPermissionAuthorized) {
        [task success:[NSNumber numberWithBool:YES]];
        return;
    }

    NSDictionary* params = task.params;
    NSString* rationale = [params objectForKey:@"rationale"];
    if (rationale != nil) {
        [jlpermission setRationale:rationale];
    }

    [jlpermission authorize:^(BOOL granted, NSError * _Nullable error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
        [jlpermission setRationale:nil]; // force reset rationale
#pragma clang diagnostic pop
        if (error) {
            [ForgeLog d:[NSString stringWithFormat:@"permissions.check '%@' failed with error: %@", permission, error]];
        }
        [task success:[NSNumber numberWithBool:granted]];
    }];
}

@end
