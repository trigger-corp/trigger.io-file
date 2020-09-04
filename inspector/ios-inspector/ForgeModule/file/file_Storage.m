//
//  file_Util.m
//  ForgeModule
//
//  Created by Antoine van Gelder on 2017/11/28.
//  Copyright © 2017 Trigger Corp. All rights reserved.
//

#import "file_Storage.h"

@implementation file_Storage

+ (ForgeFile*)writeUIImageToTemporaryFile:(UIImage*)image maxWidth:(int)maxWidth maxHeight:(int)maxHeight error:(NSError**)error {
    if (maxWidth > 0 || maxHeight > 0) {
        image = [image imageWithWidth:maxWidth andHeight:maxHeight];
    }
    
    ForgeFile *forgeFile = [ForgeFile withEndpointId:ForgeStorage.EndpointIds.Temporary
                                            resource:[ForgeStorage temporaryFileNameWithExtension:@"jpg"]];
    NSURL *destination = [ForgeStorage nativeURL:forgeFile];
    
    [UIImageJPEGRepresentation(image, 0.9) writeToURL:destination atomically:YES];
    [NSFileManager.defaultManager addSkipBackupAttributeToItemAtURL:destination];
    
    return forgeFile;
}


+ (ForgeFile*)writeVideoToTemporaryFile:(PHAsset*)asset withTask:(ForgeTask*)task videoQuality:(NSString*)videoQuality {
    return nil;
}



// Because:
//   https://stackoverflow.com/questions/3159061/
//   https://stackoverflow.com/questions/20190485

+ (void)transcode:(PHAsset*)asset withTask:(ForgeTask*)task videoQuality:(NSString*)videoQuality {
    PHVideoRequestOptions *options = [PHVideoRequestOptions new];
    options.version = PHVideoRequestOptionsVersionCurrent;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeFastFormat;
    options.networkAccessAllowed = false;

    [[PHImageManager defaultManager] requestAVAssetForVideo:asset
                                                   options:options
                                             resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        /*NSURL *destination = [NSURL fileURLWithPath:NSTemporaryDirectory()];
        NSString *timestamp = [NSString stringWithFormat: @"transcoded-%.0f", [NSDate timeIntervalSinceReferenceDate] * 1000.0];
        destination = [destination URLByAppendingPathComponent:timestamp];
        destination = [destination URLByAppendingPathExtension:@"mp4"];*/
        
        NSString *extension = @"mp4";  // TODO
        ForgeFile *forgeFile = [ForgeFile withEndpointId:ForgeStorage.EndpointIds.Temporary
                                                resource:[ForgeStorage temporaryFileNameWithExtension:extension]];
        NSURL *destination = [ForgeStorage nativeURL:forgeFile];


        NSString *exportPreset = nil;
        if ([videoQuality isEqualToString:@"low"]) {
            exportPreset = AVAssetExportPresetLowQuality;
        } else if ([videoQuality isEqualToString:@"medium"]) {
            exportPreset = AVAssetExportPresetMediumQuality;
        } else if ([videoQuality isEqualToString:@"high"]) {
            exportPreset = AVAssetExportPresetHighestQuality;
        }

        NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
        if (![compatiblePresets containsObject:exportPreset]) {
            NSLog(@"file_Util::transcode warning: No compatible preset found for '%@' quality", videoQuality);
            exportPreset = AVAssetExportPresetHighestQuality;
        }

        AVAssetExportSession *session = nil;
        session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:exportPreset];
        session.outputURL = destination;
        session.outputFileType = AVFileTypeMPEG4;

        [session exportAsynchronouslyWithCompletionHandler:^{
            switch ([session status]) {
                case AVAssetExportSessionStatusUnknown:
                    NSLog(@"file_Util::transcode status unknown");
                    break;
                case AVAssetExportSessionStatusWaiting:
                    NSLog(@"file_Util::transcode waiting");
                    break;
                case AVAssetExportSessionStatusExporting:
                    NSLog(@"file_Util::transcode busy");
                    break;
                case AVAssetExportSessionStatusFailed: {
                    NSError *error = [session error];
                    NSLog(@"file_Util::transcode failed: %@", [error localizedDescription]);
                    [task error:[error localizedDescription] type:@"UNEXPECTED_FAILURE" subtype:nil];
                    break;
                }
                case AVAssetExportSessionStatusCancelled:
                    NSLog(@"file_Util::transcode cancelled");
                    [task error:@"Operation cancelled" type:@"EXPECTED_FAILURE" subtype:nil];
                    break;
                case AVAssetExportSessionStatusCompleted: {
                    NSLog(@"file_Util::transcode completed");

                    // debug output
                    NSNumber *size;
                    [((AVURLAsset*)asset).URL getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
                    NSLog(@"Original video size is %llu bytes", [size unsignedLongLongValue]);
                    NSLog(@"Compressed video size is %llu bytes", [[[NSFileManager defaultManager] attributesOfItemAtPath:[destination path] error:nil] fileSize]);

                    [task success:[forgeFile toScriptObject]];
                    break;
                }
            }
        }];
    }];
}

@end
