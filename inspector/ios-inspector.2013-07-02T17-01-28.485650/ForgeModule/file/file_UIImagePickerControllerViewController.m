//
//  file_UIImagePickerControllerViewController.m
//  Forge
//
//  Created by Connor Dunn on 23/04/2012.
//  Copyright (c) 2012 Trigger Corp. All rights reserved.
//

#import "file_UIImagePickerControllerViewController.h"
#import "file_Delegate.h"

@interface file_UIImagePickerControllerViewController ()

@end

@implementation file_UIImagePickerControllerViewController

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
	[(file_Delegate*)self.delegate didDisappear];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

@end
