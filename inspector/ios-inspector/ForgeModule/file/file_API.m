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

#pragma mark media picker

+ (void)getImage:(ForgeTask*)task /*source:(NSString*)source*/ {
    // TODO handle options: width, height
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

+ (void)getVideo:(ForgeTask*)task /*source:(NSString*)source*/ {
    // TODO handle options: quality
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


#pragma mark operations on File objects

// TODO rename to scriptPath
+ (void)URL:(ForgeTask*)task file:(NSDictionary*)file {
    NSError *error = nil;
    ForgeFile *forgeFile = [ForgeFile withScriptObject:file error:&error];
    if (error != nil) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }
    
    [task success:[ForgeStorage scriptPath:forgeFile]];
}


+ (void)isFile:(ForgeTask*)task file:(NSDictionary*)file {
    NSError *error = nil;
    ForgeFile *forgeFile = [ForgeFile withScriptObject:file error:&error];
    if (error != nil) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }
    
    [forgeFile exists:^(BOOL exists) {
        [task success:[NSNumber numberWithBool:exists]];
    }];
}


+ (void)info:(ForgeTask*)task file:(NSDictionary*)file {
    NSError *error = nil;
    ForgeFile *forgeFile = [ForgeFile withScriptObject:file error:&error];
    if (error != nil) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }

    [forgeFile info:^(NSDictionary* info) {
        [task success:info];
    } errorBlock:^(NSString* description) {
        [task error:description type:@"UNEXPECTED_FAILURE" subtype:nil];
    }];
}

+ (void)base64:(ForgeTask*)task file:(NSDictionary*)file {
    NSError *error = nil;
    ForgeFile *forgeFile = [ForgeFile withScriptObject:file error:&error];
    if (error != nil) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }
    
    [forgeFile contents:^(NSData *data) {
        [task success:[data base64EncodingWithLineLength:0]];
    } errorBlock:^(NSError *error) {
        [task error:[error localizedDescription] type:@"EXPECTED_FAILURE" subtype:nil];
    }];
}

+ (void)string:(ForgeTask*)task file:(NSDictionary*)file {
    NSError *error = nil;
    ForgeFile *forgeFile = [ForgeFile withScriptObject:file error:&error];
    if (error != nil) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }
    
    [forgeFile contents:^(NSData *data) {
        [task success:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
    } errorBlock:^(NSError *error) {
        [task error:[error localizedDescription] type:@"EXPECTED_FAILURE" subtype:nil];
    }];
}

+ (void)remove:(ForgeTask*)task file:(NSDictionary*)file {
    NSError *error = nil;
    ForgeFile *forgeFile = [ForgeFile withScriptObject:file error:&error];
    if (error != nil) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }
    
    // restrict destructive operations to temporary, permanent and document endpoints only
    NSArray *whitelist = @[ForgeStorage.EndpointIDs.Temporary, ForgeStorage.EndpointIDs.Permanent, ForgeStorage.EndpointIDs.Documents];
    if (![whitelist containsObject:forgeFile.endpointid]) {
        return [task error:[NSString stringWithFormat:@"Cannot remove file from protected endpoint: %@", forgeFile.endpointid]
                      type:@"EXPECTED_FAILURE" subtype:nil];
    }
    
    
    [NSFileManager.defaultManager removeItemAtURL:[ForgeStorage nativeURL:forgeFile] error:&error];
    if (error != nil) {
        return [task error:@"Unable to delete file" type:@"UNEXPECTED_ERROR" subtype:nil];
    }
    
    
    if ([[file objectForKey:@"uri"] hasPrefix:@"/"]) {
        if ([[NSFileManager defaultManager] removeItemAtPath:[task.params objectForKey:@"uri"] error:nil]) {
            [task success:nil];
        } else {
            [task error:@"Unable to delete file" type:@"UNEXPECTED_ERROR" subtype:nil];
        }
    } else {
        [task error:@"Not a deletable file" type:@"BAD_INPUT" subtype:nil];
    }
}


#pragma mark operations on urls

+ (void)cacheURL:(ForgeTask*)task url:(NSString*)urlString {
    NSURL *source = [NSURL URLWithString:urlString];
    
    NSString *filename = [[NSUUID UUID] UUIDString];
    filename = [filename stringByAppendingString:@"_"];
    filename = [filename stringByAppendingString:source.path.pathComponents.lastObject];
    
    ForgeFile *forgeFile = [ForgeFile withEndpointID:ForgeStorage.EndpointIDs.Temporary resource:filename];
    NSURL *destination = [ForgeStorage nativeURL:forgeFile];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:source];
        if ([data writeToURL:destination atomically:YES]) {
            [[NSFileManager defaultManager] addSkipBackupAttributeToItemAtURL:destination];
            [task success:forgeFile.scriptObject];
        } else {
            [task error:@"Unable to save to file" type:@"UNEXPECTED_FAILURE" subtype:nil];
        }
    });
}


// TODO deprecate in favour of saveToRoute:blah filename:optional ?
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


#pragma mark operations on paths

// TODO rename to getFileFromSourceDirectory same way we renamed forge.tools.getLocal
+ (void)getLocal:(ForgeTask*)task name:(NSString*)resource {
    ForgeFile *forgeFile = [ForgeFile withEndpointID:ForgeStorage.EndpointIDs.Source resource:resource];
    [task success:forgeFile.scriptObject];
}


#pragma mark operations on filesystem

+ (void)clearCache:(ForgeTask*)task {
    NSString *temporaryPath = ForgeStorage.Directories.Temporary.path;
    for (NSString *path in [NSFileManager.defaultManager subpathsAtPath:temporaryPath]) {
        [NSFileManager.defaultManager removeItemAtPath:[temporaryPath stringByAppendingPathComponent:path] error:nil];
    }
    [task success:nil];
}


+ (void)getStorageInformation:(ForgeTask*)task {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfFileSystemForPath:[paths lastObject]
                                                                                     error:nil];    
    NSString* appPath = NSBundle.mainBundle.bundlePath;
    NSString* cachePath = ForgeStorage.Directories.Temporary.path;

    if (!attributes || !cachePath || !appPath) {
        [task error:@"Error reading storage information" type:@"UNEXPECTED_FAILURE" subtype:nil];
        return;
    }

    [task success:@{@"total": [attributes objectForKey:NSFileSystemSize],
                    @"free":  [attributes objectForKey:NSFileSystemFreeSize],
                    @"app":   [file_API _getDirectorySize:appPath],
                    @"cache": [file_API _getDirectorySize:cachePath]}];
}

+ (NSNumber*)_getDirectorySize:(NSString*)path {
    unsigned long long int result = 0;
    NSArray *files = [NSFileManager.defaultManager subpathsAtPath:path];
    for (NSString *file in files) {
        NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:[path stringByAppendingPathComponent:file] error:nil];
        result += [attrs fileSize];
    }
    return [NSNumber numberWithUnsignedLongLong:result];
}



#pragma mark permissions

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
