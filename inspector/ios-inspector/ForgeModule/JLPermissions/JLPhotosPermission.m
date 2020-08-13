//
//  JLPhotosPermissions.m
//
//  Created by Joseph Laws on 11/3/14.
//  Copyright (c) 2014 Joe Laws. All rights reserved.
//

#import "JLPhotosPermission.h"

#import <ForgeCore/JLPermissionsCore+Internal.h>

#import <Photos/Photos.h>

@implementation JLPhotosPermission {
    AuthorizationHandler _completion;
}


+ (instancetype)sharedInstance {
    static JLPhotosPermission *_instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _instance = [[JLPhotosPermission alloc] init];
    });

    return _instance;
}


#pragma mark - Photos

static PHAuthorizationStatus _authorizationStatusCompat() {
    PHAuthorizationStatus status;
    if (@available(iOS 14, *)) {
        status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
    } else {
        status = [PHPhotoLibrary authorizationStatus];
    }
    return status;
}


- (JLAuthorizationStatus)authorizationStatus {
    PHAuthorizationStatus status = _authorizationStatusCompat();
    switch (status) {
        case PHAuthorizationStatusAuthorized:
            return JLPermissionAuthorized;
        case PHAuthorizationStatusLimited:
        case PHAuthorizationStatusNotDetermined:
            return JLPermissionNotDetermined;
        case PHAuthorizationStatusDenied:
        case PHAuthorizationStatusRestricted:
            return JLPermissionDenied;
    }
}


- (void)authorize:(AuthorizationHandler)completion {
    [self authorizeWithTitle:[self defaultTitle:@"Photos"]
                     message:[self defaultMessage]
                 cancelTitle:[self defaultCancelTitle]
                  grantTitle:[self defaultGrantTitle]
                  completion:completion];
}


- (void)authorizeWithTitle:(NSString *)messageTitle
                   message:(NSString *)message
               cancelTitle:(NSString *)cancelTitle
                grantTitle:(NSString *)grantTitle
                completion:(AuthorizationHandler)completion {

    PHAuthorizationStatus status = _authorizationStatusCompat();
    switch (status) {
        case PHAuthorizationStatusAuthorized:
            if (completion) {
                completion(true, nil);
            }
            break;

        case PHAuthorizationStatusLimited:
        case PHAuthorizationStatusNotDetermined: {
            _completion = completion;
            if (/* DISABLES CODE */ (NO) && self.isExtraAlertEnabled) { // TODO
                UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:messageTitle
                                                    message:message
                                             preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:cancelTitle
                                                          style:UIAlertActionStyleCancel
                                                        handler:^(UIAlertAction * _Nonnull action) {
                    if (self->_completion) {
                        self->_completion(false, nil);
                    }
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:grantTitle
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
                    [self actuallyAuthorize];
                }]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[ForgeApp sharedApp] viewController] presentViewController:alert animated:YES completion:nil];
                });
            } else {
                [self actuallyAuthorize];
            }
        } break;

        case PHAuthorizationStatusDenied:
        case PHAuthorizationStatusRestricted: {
            if (completion) {
                completion(false, [self previouslyDeniedError]);
            }
        } break;
    }
}


- (JLPermissionType)permissionType {
    return JLPermissionPhotos;
}


- (void)actuallyAuthorize {
    PHAuthorizationStatus status = _authorizationStatusCompat();
    switch (status) {
        case PHAuthorizationStatusAuthorized:
            if (_completion) {
                _completion(true, nil);
            }
            break;

        case PHAuthorizationStatusLimited:
        case PHAuthorizationStatusNotDetermined: {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    self->_completion(true, nil);
                } else {
                    self->_completion(false, [self systemDeniedError:nil]);
                }
            }];
        } break;

        case PHAuthorizationStatusDenied:
        case PHAuthorizationStatusRestricted: {
            if (_completion) {
                _completion(false, [self previouslyDeniedError]);
            }
        } break;
    }
}


- (void)canceledAuthorization:(NSError *)error {
    if (_completion) {
        _completion(false, error);
    }
}

@end
