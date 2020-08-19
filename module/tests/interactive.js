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
if (false && forge.is.ios()) {
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
}

/*

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
            }, function (e) {
                ok(false, "forge.file.info error: " + e.message);
                start();
            });
        }, function (e) {
            ok(false, "forge.file.getImage error: " + e.message);
            start();
        });
    };
    askQuestion("When prompted select an image from the gallery", { Ok: runTest });
});


asyncTest("Gallery", 4, function() {
    var runTests = function () {
        forge.file.getImage({
            width: 100,
            height: 100
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
                        askQuestion("Is this your image:<br><img src='" + url + "' style='max-width: 100px; max-height: 100px'>", { Yes: function () {
                            ok(true, "Success with forge.file.URL");
                            forge.file.base64(file, function (data) {
                                askQuestion("Is this also your image:<br><img src='data:image/jpg;base64,"+data+"' style='max-width: 100px; max-height: 100px'>", { Yes: function () {
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
                    }, api_error("file.url"));
                }, api_error("file.isFile"));
            }, No: function () {
                ok(false, "User claims failure");
                start();
            }});
        }, api_error("file.getImage"));
    };
    askQuestion("In this test use the gallery to select a picture when prompted", { Ok: runTests });
});
*/

asyncTest("Embedding video in webview", 1, function() {
    var runTest = function () {
        forge.file.getVideo({
            videoQuality: "low"
        }, function (file) {
            //forge.file.URL(file, function (url) { // TODO unbreak this
                url = file.uri;
                askQuestion("Did your video just play: <video controls autoplay playsinline width=192 src='" + url + "'></video>", {
                    Yes: function () {
                        ok(true, "video capture successful");
                        start();
                    }, No: function () {
                        ok(false, "didn't play back just-captured video");
                        start();
                    }
                });
            //}, api_error("file.URL"));
        }, function (e) {
            ok(false, "API call failure: "+e.message);
            start();
        });
    };
    askQuestion("When prompted select a video from the gallery", { Ok: runTest });
});


asyncTest("Cancel", 1, function() {
    var runTest = function () {
        forge.file.getImage(function () {
            ok(false, "forge.file.getImage returned success");
            start();
        }, function (e) {
            ok(true, "API error callback: "+e.message);
            start();
        });
    };
    askQuestion("In this test press back or cancel rather than choosing an image", { Ok: runTest });
});


asyncTest("File cache - With delete", 6, function () {
    askQuestion("Can you see the following image (loaded from trigger.io):<br><img src='https://trigger.io/forge-static/img/trigger-light/trigger-io-command-line.jpg'>", { Yes: function () {
        ok(true, "Image loaded from trigger.io");
        forge.file.cacheURL("https://trigger.io/forge-static/img/trigger-light/trigger-io-command-line.jpg", function (file) {
            ok(true, "file.cacheURL claims success");
            forge.file.URL(file, function (url) {
                ok(true, "file.URL claims success");
                askQuestion("Is this the same image:<br><img src='"+url+"'>", { Yes: function () {
                    ok(true, "Image cached correctly");
                    forge.file.remove(file, function () {
                        ok(true, "file.remove claims success");
                        forge.file.isFile(file, function (exists) {
                            ok(!exists, "File deleted");
                            start();
                        });
                    }, function (e) {
                        ok(false, "API error callback: "+e.message);
                        start();
                    });
                }, No: function () {
                    ok(false, "User claims failure");
                    start();
                }});
            }, function (e) {
                ok(false, "API error callback: "+e.message);
                start();
            });
        }, function (e) {
            ok(false, "API error callback: "+e.message);
            start();
        });
    }, No: function () {
        ok(false, "Image not loaded");
        start();
    }});
});


asyncTest("File saving", 4, function () {
    askQuestion("Can you see the following image (loaded from trigger.io):<br><img src='https://trigger.io/forge-static/img/trigger-t.png'>", { Yes: function () {
        ok(true, "Trigger T loaded from trigger.io");
        forge.file.saveURL("https://trigger.io/forge-static/img/trigger-t.png", function (file) {
            ok(true, "file.saveURL claims success");
            forge.file.URL(file, function (url) {
                ok(true, "file.URL claims success");
                askQuestion("Is this the same image:<br><img src='"+url+"'>", { Yes: function () {
                    ok(true, "Image cached correctly");
                    start();
                }, No: function () {
                    ok(false, "User claims failure");
                    start();
                }});
            }, function (e) {
                ok(false, "API error callback: "+e.message);
                start();
            });
        }, function (e) {
            ok(false, "API error callback: "+e.message);
            start();
        });
    }, No: function () {
        ok(false, "Image not loaded");
        start();
    }});
});


asyncTest("File cache - With clearCache", 6, function () {
    askQuestion("Can you see the following image (loaded from trigger.io):<br><img src='https://trigger.io/forge-static/img/trigger-light/trigger-io-command-line.jpg'>", { Yes: function () {
        ok(true, "Image loaded from trigger.io");
        forge.file.cacheURL("https://trigger.io/forge-static/img/trigger-light/trigger-io-command-line.jpg", function (file) {
            ok(true, "file.cacheURL claims success");
            forge.file.URL(file, function (url) {
                ok(true, "file.URL claims success");
                askQuestion("Is this the same image:<br><img src='"+url+"'>", { Yes: function () {
                    ok(true, "Image cached correctly");
                    forge.file.clearCache(function () {
                        ok(true, "file.clearCache claims success");
                        forge.file.isFile(file, function (exists) {
                            ok(!exists, "File deleted");
                            start();
                        });
                    }, function (e) {
                        ok(false, "API error callback: "+e.message);
                        start();
                    });
                }, No: function () {
                    ok(false, "User claims failure");
                    start();
                }});
            }, function (e) {
                ok(false, "API error callback: "+e.message);
                start();
            });
        }, function (e) {
            ok(false, "API error callback: "+e.message);
            start();
        });
    }, No: function () {
        ok(false, "Image not loaded");
        start();
    }});
});



asyncTest("Diskspace", 1, function () {
    forge.file.getStorageInformation(function (info) {
        var msg = "Device storage information: <ul>";
        var gig = Math.pow(1024, 3);
        msg += "<li>Total: " + info.total / gig + "</li>";
        msg += "<li>Free: " + info.free / gig + "</li>";
        msg += "<li>App: " + info.app / gig + "</li>";
        msg += "<li>Cache: " + info.cache / gig + "</li>";
        msg += "</ul>Does this look correct?";
        askQuestion(msg, {
            Yes: function () {
                ok(true, "Success with forge.file.getStorageInformation");
                start();

            }, No: function () {
                ok(false, "User claims failure with forge.file.getStorageInformation");
                start();
            }
        });
    }, function (e) {
        ok(false, "API call failure: "+e.message);
        start();
    });
});
