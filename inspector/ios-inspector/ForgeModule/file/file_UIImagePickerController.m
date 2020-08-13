//
//  file_UIImagePickerControllerViewController.m
//  Forge
//
//  Created by Connor Dunn on 23/04/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import "file_UIImagePickerController.h"
#import "file_Delegate_deprecated.h"

@interface file_UIImagePickerController ()

@end

@implementation file_UIImagePickerController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
	[(file_Delegate_deprecated*)self.delegate didDisappear];
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(BOOL)prefersStatusBarHidden {
	if (self.sourceType == UIImagePickerControllerSourceTypeCamera) {
		return YES;
	} else {
		return NO;
	}
}

@end
