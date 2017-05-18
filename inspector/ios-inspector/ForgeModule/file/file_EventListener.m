#import "file_EventListener.h"
#import "file_API.h"

@implementation file_EventListener

+ (void)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSBundle *bundle = [NSBundle mainBundle];

    if ([bundle objectForInfoDictionaryKey:@"io_trigger_dialog_capture_camera_description"])
        io_trigger_dialog_capture_camera_description = [bundle objectForInfoDictionaryKey:@"io_trigger_dialog_capture_camera_description"];
    if ([bundle objectForInfoDictionaryKey:@"io_trigger_dialog_capture_source_camera"])
        io_trigger_dialog_capture_source_camera = [bundle objectForInfoDictionaryKey:@"io_trigger_dialog_capture_source_camera"];
    if ([bundle objectForInfoDictionaryKey:@"io_trigger_dialog_capture_source_gallery"])
        io_trigger_dialog_capture_source_gallery = [bundle objectForInfoDictionaryKey:@"io_trigger_dialog_capture_source_gallery"];
    if ([bundle objectForInfoDictionaryKey:@"io_trigger_dialog_capture_pick_source"])
        io_trigger_dialog_capture_pick_source = [bundle objectForInfoDictionaryKey:@"io_trigger_dialog_capture_pick_source"];
    if ([bundle objectForInfoDictionaryKey:@"io_trigger_dialog_cancel"])
        io_trigger_dialog_cancel = [bundle objectForInfoDictionaryKey:@"io_trigger_dialog_cancel"];
}

@end
