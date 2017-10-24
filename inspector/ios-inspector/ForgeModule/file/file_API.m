//
//  file_API.m
//  Forge
//
//  Created by Connor Dunn on 14/03/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import "file_API.h"
#import "file_Delegate.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <ForgeCore/UIActionSheet+UIAlertInView.h>

@implementation file_API

NSString *io_trigger_dialog_capture_camera_description = @"Not Used";
NSString *io_trigger_dialog_capture_source_camera = @"Camera";
NSString *io_trigger_dialog_capture_source_gallery = @"Gallery";
NSString *io_trigger_dialog_capture_pick_source = @"Pick a source";
NSString *io_trigger_dialog_cancel = @"Cancel";

+ (void)getImage:(ForgeTask*)task source:(NSString*)source {
    file_Delegate *delegate = [[file_Delegate alloc] initWithTask:task andParams:task.params andType:(NSString *)kUTTypeImage];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]
        && ![source isEqualToString:@"camera"] && ![source isEqualToString:@"gallery"]) {
        UIActionSheet *menu = [[UIActionSheet alloc] initWithTitle:io_trigger_dialog_capture_pick_source
                                                          delegate:delegate
                                                 cancelButtonTitle:io_trigger_dialog_cancel
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:io_trigger_dialog_capture_source_camera, io_trigger_dialog_capture_source_gallery, nil];
        menu.delegate = delegate;
        if ([menu respondsToSelector:@selector(alertInView:)]) {
            [menu alertInView:[[ForgeApp sharedApp] viewController].view];
        } else {
            [menu showInView:[[ForgeApp sharedApp] viewController].view];
        }
    } else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]
               && [source isEqualToString:@"camera"]) {
        [delegate actionSheet:nil didDismissWithButtonIndex:0];
    } else {
        [delegate actionSheet:nil didDismissWithButtonIndex:1];
    }
}

+ (void)getVideo:(ForgeTask*)task source:(NSString*)source {
    file_Delegate *delegate = [[file_Delegate alloc] initWithTask:task andParams:task.params andType:(NSString *)kUTTypeMovie];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]
        && ![source isEqualToString:@"camera"] && ![source isEqualToString:@"gallery"]) {
        UIActionSheet *menu = [[UIActionSheet alloc] initWithTitle:io_trigger_dialog_capture_pick_source
                                                          delegate:delegate
                                                 cancelButtonTitle:io_trigger_dialog_cancel
                                            destructiveButtonTitle:nil otherButtonTitles:io_trigger_dialog_capture_source_camera, io_trigger_dialog_capture_source_gallery, nil];
        menu.delegate = delegate;
        if ([menu respondsToSelector:@selector(alertInView:)]) {
            [menu alertInView:[[ForgeApp sharedApp] viewController].view];
        } else {
            [menu showInView:[[ForgeApp sharedApp] viewController].view];
        }
    } else if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]
               && [source isEqualToString:@"camera"]) {
        [delegate actionSheet:nil didDismissWithButtonIndex:0];
    } else {
        [delegate actionSheet:nil didDismissWithButtonIndex:1];
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
    NSString *uuid = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, CFUUIDCreate(NULL));
    NSString *tempFile = [[[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:uuid] stringByAppendingString:[[[[NSURL URLWithString:url] path] pathComponents] lastObject]];

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

@end
