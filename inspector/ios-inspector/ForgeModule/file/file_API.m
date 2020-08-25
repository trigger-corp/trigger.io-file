//
//  file_API.m
//  Forge
//
//  Copyright (c) 2020 Trigger Corp. All rights reserved.
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

+ (void)getImage:(ForgeTask*)task {
    // TODO handle options: width, height
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
        configuration.selectionLimit = 1;
        configuration.filter = PHPickerFilter.imagesFilter;
        file_PHPickerDelegate *delegate = [file_PHPickerDelegate withTask:task configuration:configuration];
        [delegate openPicker];
    } else {
        file_Delegate_deprecated *delegate = [file_Delegate_deprecated withTask:task type:(NSString*)kUTTypeImage];
        [delegate openPicker];
    }
}


+ (void)getVideo:(ForgeTask*)task {
    // TODO handle options: quality
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
        configuration.selectionLimit = 1;
        configuration.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
            PHPickerFilter.videosFilter,
            // TODO PHPickerFilter.livePhotosFilter 
        ]];
        file_PHPickerDelegate *delegate = [file_PHPickerDelegate withTask:task configuration:configuration];
        [delegate openPicker];
    } else {
        file_Delegate_deprecated *delegate = [file_Delegate_deprecated withTask:task type:(NSString*)kUTTypeMovie];
        [delegate openPicker];
    }
}


#pragma mark operations on resource paths

// used to be called getLocall, returns a File like: { endpoint: "/src", resource: "/path/to/resource.html" }
+ (void)getFileFromSourceDirectory:(ForgeTask*)task resource:(NSString*)resource {
    ForgeFile *forgeFile = [ForgeFile withEndpointID:ForgeStorage.EndpointIDs.Source resource:resource];
    [task success:forgeFile.scriptObject];
}

// returns a fully qualified url like: https://localhost:1234/src/path/to/resource.html
+ (void)getURLFromSourceDirectory:(ForgeTask*)task resource:(NSString*)resource {
    if ([resource hasPrefix:@"http://"] || [resource hasPrefix:@"https://"]) {
        [task success:resource];
        
    } else {
        ForgeFile *file = [ForgeFile withEndpointID:ForgeStorage.EndpointIDs.Source resource:resource];
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
        return [task error:[NSString stringWithFormat:@"Unable to delete file: %@", error.localizedDescription]
                      type:@"UNEXPECTED_ERROR" subtype:nil];
    }
    
    [task success:nil];
}


#pragma mark operations on urls

+ (void)cacheURL:(ForgeTask*)task url:(NSString*)url {
    NSURL *source = [NSURL URLWithString:url];
    
    NSString *filename = [ForgeStorage temporaryFileNameWithExtension:source.lastPathComponent];
    ForgeFile *forgeFile = [ForgeFile withEndpointID:ForgeStorage.EndpointIDs.Temporary
                                            resource:filename];
    
    NSURL *destination = [ForgeStorage nativeURL:forgeFile];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:source];
        if ([data writeToURL:destination atomically:YES]) {
            [NSFileManager.defaultManager addSkipBackupAttributeToItemAtURL:destination];
            [task success:forgeFile.scriptObject];
        } else {
            [task error:@"Unable to cache url" type:@"UNEXPECTED_FAILURE" subtype:nil];
        }
    });
}


// TODO deprecate in favour of saveToRoute:blah filename:optional ?
+ (void)saveURL:(ForgeTask*)task url:(NSString*)url {
    NSURL *source = [NSURL URLWithString:url];

    NSString *filename = [ForgeStorage temporaryFileNameWithExtension:source.lastPathComponent];
    ForgeFile *forgeFile = [ForgeFile withEndpointID:ForgeStorage.EndpointIDs.Permanent
                                            resource:filename];
    
    NSURL *destination = [ForgeStorage nativeURL:forgeFile];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:source];
        if ([data writeToURL:destination atomically:YES]) {
            [NSFileManager.defaultManager addSkipBackupAttributeToItemAtURL:destination];
            [task success:forgeFile.scriptObject];
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
