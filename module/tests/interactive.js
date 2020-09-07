/* global forge, module, asyncTest, start, ok, askQuestion */

module("forge.file");


// helper for logging consistent and informative api errors
var api_error = function (api) {
    return function (e) {
        ok(false, api + " failure: " + e.message);
        start();
    };
};


// TODO looks like we're losing this, maybe move some of it to the capture module
// permissions module native code has to be baked into the file module to avoid app store rejections
/*if (false && forge.is.ios()) {
    if (!forge.permissions) {
        forge.permissions = {
            check: function (permission, success, error) {
                forge.internal.call("file.permissions_check", {
                    permission: "ios.permission.photos"
                }, success, error);

            },
            request: function (permission, rationale, success, error) {
                forge.internal.call("file.permissions_request", {
                    permission: "ios.permission.photos",
                    rationale: rationale
                }, success, error);
            },
            photos: {
                "read": "photos_read"
            }
        };
    }

    var rationale = "Can haz fileburger?";

    asyncTest("File permission request denied.", 1, function() {
        var runTest = function() {
            forge.permissions.request(forge.permissions.photos.read, rationale, function (allowed) {
                if (!allowed) {
                    ok(true, "Permission request denied.");
                    start();
                } else {
                    ok(false, "Permission request was allowed. Expected permission denied.");
                    start();
                }
            }, function () {
                ok(false, "API method returned failure");
                start();
            });
        };
        forge.permissions.check(forge.permissions.photos.read, function (allowed) {
            if (allowed) {
                ok(true, "Already have permission");
                start();
            } else {
                askQuestion("When prompted, deny the permission request", { Ok: runTest });
            }
        });
    });

    asyncTest("File permission request allowed.", 1, function() {
        var runTest = function() {
            forge.permissions.request(forge.permissions.photos.read, rationale, function (allowed) {
                if (allowed) {
                    ok(true, "Permission request allowed.");
                    start();
                } else {
                    ok(false, "Permission request was denied. Expected permission allowed.");
                    start();
                }
            }, function () {
                ok(false, "API method returned failure");
                start();
            });
        };
        askQuestion("If prompted, allow the permission request", { Ok: runTest });
    });
}*/


// - media pickers ------------------------------------------------------------

asyncTest("Select image from gallery and check file info", 2, function() {
    var runTest = function () {
        forge.file.getImage(function (file) {
            forge.file.info(file, function (info) {
                ok(true, "file.info claims success");
                askQuestion("Does the following file information describe the file: " +
                            JSON.stringify(info), {
                                Yes: function () {
                                    ok(true, "File information is correct");
                                    start();
                                },
                                No: function () {
                                    ok(false, "User claims failure");
                                    start();
                                }
                            });
            }, api_error("file.info"));
        }, api_error("file.getImage"));
    };
    askQuestion("When prompted select an image from the gallery", { Ok: runTest });
});

asyncTest("Select resized image from gallery and check file info", 2, function() {
    var runTest = function () {
        forge.file.getImage({
            width: 256,
            height: 256
        }, function (file) {
            forge.file.info(file, function (info) {
                ok(true, "file.info claims success");
                askQuestion("Is the file size of your image smaller this time?" +
                            JSON.stringify(info), {
                                Yes: function () {
                                    ok(true, "File information is correct");
                                    start();
                                },
                                No: function () {
                                    ok(false, "User claims failure");
                                    start();
                                }
                            });
            }, api_error("file.info"));
        }, api_error("file.getImage"));
    };
    askQuestion("When prompted select the same image from the gallery", { Ok: runTest });
});


asyncTest("Gallery", 4, function() {
    var runTests = function () {
        forge.file.getImage({
            width: 256,
            height: 256
        }, function (file) {
            askQuestion("Were you just prompted to select an image?", { Yes: function () {
                ok(true, "Success");
                forge.file.isFile(file, function (is) {
                    if (is) {
                        ok(true, "forge.file.isFile is true");
                    } else {
                        ok(false, "forge.file.isFile is false");
                    }
                    forge.file.URL(file, function (url) {
                        askQuestion("Is this your image:<br><img src='" +
                                    url +
                                    "' style='max-width: 512px; max-height: 512px' />", { Yes: function () {
                            ok(true, "Success with forge.file.URL");
                            forge.file.base64(file, function (data) {
                                askQuestion("Is this also your image:<br><img src='data:image/jpg;base64," +
                                            data +
                                            "' style='max-width:512px; max-height:512px' />", { Yes: function () {
                                    ok(true, "Success with forge.file.base64");
                                    start();
                                }, No: function () {
                                    ok(false, "User claims failure with forge.file.base64");
                                    start();
                                }});
                            }, api_error("file.base64"));
                        }, No: function () {
                            ok(false, "User claims failure with forge.file.URL");
                            start();
                        }});
                    }, api_error("file.URL"));
                }, api_error("file.isFile"));
            }, No: function () {
                ok(false, "User claims failure");
                start();
            }});
        }, api_error("file.getImage"));
    };
    askQuestion("In this test use the gallery to select a picture when prompted", { Ok: runTests });
});


asyncTest("Select multiple images from gallery", 2, function() {
    var runTest = function () {
        forge.file.getImages({
            width: 256,
            height: 256
        }, function (files) {
            ok(files.length === 3, "correct number of images");
            var images = files.reduce(function (ret, file, index, files) {
                return ret + "<img src='" + file.endpoint + "/" + file.resource + "' style='max-width: 512px; max-height: 512px' />";
            }, "");
            askQuestion("Are these your images: " + images, {
                Yes: function () {
                    ok(true, "multiple image selection successful");
                    start();
                }, No: function () {
                    ok(false, "multiple image selection failed failed");
                    start();
                }
            });

        }, api_error("file.getImages"));
    };
    askQuestion("When prompted select three images from the gallery", { Ok: runTest });
});


asyncTest("Embedding video in webview", 1, function() {
    var runTest = function () {
        forge.file.getVideo({
        }, function (file) {
            forge.file.URL(file, function (url) {
                askQuestion("Did your video just play: <video controls autoplay playsinline style='max-width:512px; max-height:512px' src='" + url + "'></video>", {
                    Yes: function () {
                        ok(true, "video playback successful");
                        start();
                    }, No: function () {
                        ok(false, "video playback failed");
                        start();
                    }
                });
            }, api_error("file.URL"));
        }, api_error("file.getVideo"));
    };
    askQuestion("When prompted select a video from the gallery", { Ok: runTest });
});


if (forge.is.ios()) {
    asyncTest("Embedding transcoded video in webview", 1, function() {
        var runTest = function () {
            forge.file.getVideo({
                videoQuality: "low"
            }, function (file) {
                forge.file.URL(file, function (url) {
                    askQuestion("Did a smaller version of your video just play: <video controls autoplay playsinline style='max-width:512px; max-height:512px' src='" + url + "'></video>", {
                        Yes: function () {
                            ok(true, "video playback successful");
                            start();
                        }, No: function () {
                            ok(false, "video playback failed");
                            start();
                        }
                    });
                }, api_error("file.URL"));
            }, api_error("file.getVideo"));
        };
        askQuestion("When prompted select the same video from the gallery", { Ok: runTest });
    });
}


asyncTest("Select multiple videos from gallery", 2, function() {
    var runTest = function () {
        forge.file.getVideos(function (files) {
            ok(files.length === 3, "correct number of videos");
            var videos = files.reduce(function (ret, file, index, files) {
                return ret + "<video controls autoplay playsinline style='max-width:256px; max-height:256px' src='" + file.endpoint + "/" + file.resource + "'></video>";
            }, "");
            askQuestion("Are these your videos: " + videos, {
                Yes: function () {
                    ok(true, "multiple video selection successful");
                    start();
                }, No: function () {
                    ok(false, "multiple video selection failed failed");
                    start();
                }
            });

        }, api_error("file.getVideos"));
    };
    askQuestion("When prompted select three videos from the gallery", { Ok: runTest });
});


asyncTest("Cancel", 1, function() {
    var runTest = function () {
        forge.file.getImage(function () {
            ok(false, "forge.file.getImage returned success");
            start();
        }, function (e) {
            ok(true, "User pressed cancel");
            start();
        });
    };
    askQuestion("In this test press back or cancel rather than choosing an image", { Ok: runTest });
});


// - operations on urls -------------------------------------------------------

asyncTest("File cache - With delete", 6, function () {
    askQuestion("Can you see the following image (loaded from trigger.io):<br><img src='https://trigger.io/forge-static/img/trigger-light/trigger-io-command-line.jpg' />", { Yes: function () {
        ok(true, "Image loaded from trigger.io");
        forge.file.cacheURL("https://trigger.io/forge-static/img/trigger-light/trigger-io-command-line.jpg", function (file) {
            ok(true, "file.cacheURL claims success");
            forge.file.URL(file, function (url) {
                ok(true, "file.URL claims success");
                askQuestion("Is this the same image:<br><img src='" + url + "' />", { Yes: function () {
                    ok(true, "Image cached correctly");
                    forge.file.remove(file, function () {
                        ok(true, "file.remove claims success");
                        forge.file.isFile(file, function (exists) {
                            ok(!exists, "File deleted");
                            start();
                        });
                    }, api_error("file.remove"));
                }, No: function () {
                    ok(false, "User claims failure");
                    start();
                }});
            }, api_error("file.URL"));
        }, api_error("file.cacheURL"));
    }, No: function () {
        ok(false, "Image not loaded");
        start();
    }});
});

asyncTest("File saving", 4, function () {
    askQuestion("Can you see the following image (loaded from trigger.io):<br><img src='https://trigger.io/forge-static/img/trigger-t.png' />", { Yes: function () {
        ok(true, "Trigger T loaded from trigger.io");
        forge.file.saveURL("https://trigger.io/forge-static/img/trigger-t.png", function (file) {
            ok(true, "file.saveURL claims success");
            forge.file.URL(file, function (url) {
                ok(true, "file.URL claims success");
                askQuestion("Is this the same image:<br><img src='" + url + "' />", { Yes: function () {
                    ok(true, "Image cached correctly");
                    start();
                }, No: function () {
                    ok(false, "User claims failure");
                    start();
                }});
            }, api_error("file.URL"));
        }, api_error("file.saveURL"));
    }, No: function () {
        ok(false, "Image not loaded");
        start();
    }});
});


// - operations on filesystem -------------------------------------------------

function showStorageSizeInformation(size) {
    var meg = Math.pow(1024, 2);
    var gig = Math.pow(1024, 3);

    var message = "Device storage size information: <ul>";
    message += "<li>Total: " + size.total / gig + " GB</li>";
    message += "<li>Free: " + size.free / gig + " GB</li>";
    message += "<li>App: " + size.app / meg + " MB</li>";
    message += "<li>Endpoints:";
    message += "  <ul>";
    message += "    <li>/forge: " + size.endpoints.forge / meg + " MB</li>";
    message += "    <li>/src: " + size.endpoints.source / meg + " MB</li>";
    message += "    <li>/temporary: " + size.endpoints.temporary / meg + " MB</li>";
    message += "    <li>/permanent: " + size.endpoints.permanent / meg + " MB</li>";
    message += "    <li>/documents: " + size.endpoints.documents / meg + " MB</li>";
    message += "  </ul>";
    message += "</ul>";

    return message;
}


asyncTest("Device storage", 1, function () {
    forge.file.getStorageSizeInformation(function (size) {
        var msg = showStorageSizeInformation(size);
        msg += "Does this look correct?";
        askQuestion(msg, {
            Yes: function () {
                ok(true, "Success with forge.file.getStorageSizeInformation");
                start();

            }, No: function () {
                ok(false, "User claims failure with forge.file.getStorageSizeInformation");
                start();
            }
        });
    }, api_error("file.getStorageSizeInformation"));
});


asyncTest("Clear Cache", 3, function () {
    var runTest = function () {
        forge.file.clearCache(function () {
            ok(true);
            forge.file.getStorageSizeInformation(function (size) {
                ok(true);
                var msg = showStorageSizeInformation(size);
                msg += "Does this look correct?";
                askQuestion(msg, {
                    Yes: function () {
                        ok(true, "Success with forge.file.getStorageSizeInformation");
                        start();

                    }, No: function () {
                        ok(false, "User claims failure with forge.file.getStorageSizeInformation");
                        start();
                    }
                });
            }, api_error("file.getStorageSizeInformation"));
        }, api_error("file.clearCache"));
    };
    askQuestion("Click ok to clear the device cache and show device storage size information again", { Ok: runTest });
});
