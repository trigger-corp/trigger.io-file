//
//  file_API.m
//  Forge
//
//  Copyright (c) 2020 Trigger Corp. All rights reserved.
//

#import <CoreServices/UTCoreTypes.h>

#import <Photos/Photos.h>
#import <PhotosUI/PHPicker.h>

#import "file_API.h"
#import "file_PHPickerDelegate.h"
#import "file_Delegate_deprecated.h"


@implementation file_API

#pragma mark media picker

+ (void)getImages:(ForgeTask*)task {
    int selectionLimit = task.params[@"selectionLimit"] ? [task.params[@"selectionLimit"] intValue] : 1;
    
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
        configuration.selectionLimit = selectionLimit;
        configuration.filter = PHPickerFilter.imagesFilter;
        configuration.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCompatible;
        file_PHPickerDelegate *delegate = [file_PHPickerDelegate withTask:task configuration:configuration];
        [delegate openPicker];
    } else {
        file_Delegate_deprecated *delegate = [file_Delegate_deprecated withTask:task type:(NSString*)kUTTypeImage];
        [delegate openPicker];
    }
}


+ (void)getVideos:(ForgeTask*)task {
    // TODO we need Photo Library permissions if we want to transcode video
    if (task.params[@"videoQuality"] && ![task.params[@"videoQuality"] isEqualToString:@"default"]) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status != PHAuthorizationStatusAuthorized) {
                [task error:@"Permission denied. User didn't grant access to storage." type:@"EXPECTED_FAILURE" subtype:nil];
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [file_API _getVideos:task];
            });
        }];
    } else {
        [file_API _getVideos:task];
    }
}

+ (void)_getVideos:(ForgeTask*)task {
    int selectionLimit = task.params[@"selectionLimit"] ? [task.params[@"selectionLimit"] intValue] : 1;
    
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
        configuration.selectionLimit = selectionLimit;
        configuration.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
            PHPickerFilter.videosFilter,
            // TODO PHPickerFilter.livePhotosFilter
        ]];
        configuration.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCompatible;
        file_PHPickerDelegate *delegate = [file_PHPickerDelegate withTask:task configuration:configuration];
        [delegate openPicker];
    } else {
        file_Delegate_deprecated *delegate = [file_Delegate_deprecated withTask:task type:(NSString*)kUTTypeMovie];
        [delegate openPicker];
    }
}



#pragma mark operations on resource paths

// used to be called getLocal, returns a File like: { endpoint: "/src", resource: "/path/to/resource.html" }
+ (void)getFileFromSourceDirectory:(ForgeTask*)task resource:(NSString*)resource {
    ForgeFile *forgeFile = [ForgeFile withEndpointId:ForgeStorage.EndpointIds.Source resource:resource];
    [task success:[forgeFile toScriptObject]];
}

// returns a fully qualified url like: https://localhost:1234/src/path/to/resource.html
+ (void)getURLFromSourceDirectory:(ForgeTask*)task resource:(NSString*)resource {
    if ([resource hasPrefix:@"http://"] || [resource hasPrefix:@"https://"]) {
        [task success:resource];
        
    } else {
        ForgeFile *file = [ForgeFile withEndpointId:ForgeStorage.EndpointIds.Source resource:resource];
        [task success:[ForgeStorage scriptURL:file].absoluteString];
    }
}


#pragma mark operations on File objects

// returns an absolute path like: /endpoint/with/path/to/resource.html
+ (void)getScriptPath:(ForgeTask*)task file:(NSDictionary*)file {
    NSError *error = nil;
    ForgeFile *forgeFile = [ForgeFile withScriptObject:file error:&error];
    if (error != nil) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }
    
    [task success:[ForgeStorage scriptPath:forgeFile]];
}

// used to be called URL, returns an absolute URL like: https://localhost:1234/src/path/to/resource.html
+ (void)getScriptURL:(ForgeTask*)task file:(NSDictionary*)file {
    NSError *error = nil;
    ForgeFile *forgeFile = [ForgeFile withScriptObject:file error:&error];
    if (error != nil) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }
    
    [task success:[ForgeStorage scriptURL:forgeFile].absoluteString];
}


+ (void)exists:(ForgeTask*)task file:(NSDictionary*)file {
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

    [forgeFile attributes:^(NSDictionary *info) {
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
    
    [forgeFile remove:^{
        [task success:nil];
    } errorBlock:^(NSError *error) {
        return [task error:error.localizedDescription type:@"EXPECTED_FAILURE" subtype:nil];
    }];    
}


#pragma mark operations on urls

+ (void)cacheURL:(ForgeTask*)task url:(NSString*)url {
    NSURL *source = [NSURL URLWithString:url];
    
    NSString *filename = [ForgeStorage temporaryFileNameWithExtension:source.lastPathComponent];
    ForgeFile *forgeFile = [ForgeFile withEndpointId:ForgeStorage.EndpointIds.Temporary
                                            resource:filename];
    
    NSURL *destination = [ForgeStorage nativeURL:forgeFile];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:source];
        if ([data writeToURL:destination atomically:YES]) {
            [NSFileManager.defaultManager addSkipBackupAttributeToItemAtURL:destination];
            [task success:[forgeFile toScriptObject]];
        } else {
            [task error:@"Unable to cache url" type:@"UNEXPECTED_FAILURE" subtype:nil];
        }
    });
}


// TODO deprecate in favour of saveToRoute:blah filename:optional ?
+ (void)saveURL:(ForgeTask*)task url:(NSString*)url {
    NSURL *source = [NSURL URLWithString:url];

    NSString *filename = [ForgeStorage temporaryFileNameWithExtension:source.lastPathComponent];
    ForgeFile *forgeFile = [ForgeFile withEndpointId:ForgeStorage.EndpointIds.Permanent
                                            resource:filename];
    
    NSURL *destination = [ForgeStorage nativeURL:forgeFile];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:source];
        if ([data writeToURL:destination atomically:YES]) {
            [NSFileManager.defaultManager addSkipBackupAttributeToItemAtURL:destination];
            [task success:[forgeFile toScriptObject]];
        } else {
            [task error:@"Unable to save url" type:@"UNEXPECTED_FAILURE" subtype:nil];
        }
    });
}


#pragma mark operations on filesystem

+ (void)clearCache:(ForgeTask*)task {
    NSString *temporaryPath = ForgeStorage.Directories.Temporary.path;
    for (NSString *path in [NSFileManager.defaultManager subpathsAtPath:temporaryPath]) {
        [NSFileManager.defaultManager removeItemAtPath:[temporaryPath stringByAppendingPathComponent:path] error:nil];
    }
    [task success:nil];
}


+ (void)getStorageSizeInformation:(ForgeTask*)task {
    NSError *error = nil;
    NSDictionary *sizeInformation = [ForgeStorage getSizeInformation:&error];
    if (error != nil) {
        [task error:@"Error reading storage size information" type:@"UNEXPECTED_FAILURE" subtype:nil];
        return;
    }
    [task success:sizeInformation];
}


#pragma mark permissions

/*+ (void)permissions_check:(ForgeTask*)task permission:(NSString *)permission {
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
}*/

@end
