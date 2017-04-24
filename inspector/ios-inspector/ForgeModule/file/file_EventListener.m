#import "file_EventListener.h"
#import "file_API.h"

@implementation file_EventListener

+ (void)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    io_trigger_dialog_capture_camera_description = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"io_trigger_dialog_capture_camera_description"];
    io_trigger_dialog_capture_source_camera = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"io_trigger_dialog_capture_source_camera"];
    io_trigger_dialog_capture_source_gallery = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"io_trigger_dialog_capture_source_gallery"];
    io_trigger_dialog_capture_pick_source = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"io_trigger_dialog_capture_pick_source"];
    io_trigger_dialog_cancel = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"io_trigger_dialog_cancel"];
}

@end
