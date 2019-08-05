/* global forge, module, asyncTest, start, ok, askQuestion */

module("forge.file");

if (forge.request) {
    var upload_url = "https://httpbin.org/post";

    asyncTest("File upload", 1, function() {
        forge.file.getVideo(function (file) {
            forge.request.ajax({
                url: upload_url,
                files: [file],
                success: function (data) {
                    data = JSON.parse(data);
                    forge.logging.log("Response: " + JSON.stringify(data.headers));
                    start();
                },
                error: function () {
                    ok(false, "Ajax error callback");
                    start();
                }
            });
        });
    });

    asyncTest("Raw File upload", 1, function() {
        forge.file.getVideo(function (file) {
            forge.request.ajax({
                url: upload_url,
                files: [file],
                fileUploadMethod: "raw",
                success: function (data) {
                    data = JSON.parse(data);
                    forge.logging.log("Response: " + JSON.stringify(data.headers));
                    ok(true);
                    start();
                },
                error: function () {
                    ok(false, "Ajax error callback");
                    start();
                }
            });
        });
    });

}

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
                ok(false, "API call failure: " + e.message);
                start();
            });
        });
    };
    askQuestion("When prompted select a file from the gallery", { Ok: runTest });
});



if (forge.is.ios()) {
    asyncTest("Select a video with low quality and check file info", 2, function() {
        var runTest = function () {
            forge.file.getVideo({
                source: "gallery",
                videoQuality: "low"
            }, function (file) {
                forge.file.info(file, function (info) {
                    ok(true, "file.info claims success");
                    askQuestion("Is the file size smaller: " +
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
                    ok(false, "API call failure: " + e.message);
                    start();
                });
            });
        };
        askQuestion("When prompted select the video you recorded from the gallery", { Ok: runTest });
    });
}


asyncTest("Embedding video in webview", 1, function() {
    forge.file.getVideo({
        source: "gallery",
        videoQuality: "low"
    }, function (file) {
        forge.file.URL(file, function (url) {
            askQuestion("Did your video just play: <video controls autoplay width=192 src='" + url + "'></video>", {
                Yes: function () {
                    ok(true, "video capture successful");
                    start();
                }, No: function () {
                    ok(false, "didn't play back just-captured video");
                    start();
                }
            });
        }, function (e) {
            ok(false, "API call failure: "+e.message);
            start();
        });
    }, function (e) {
        ok(false, "API call failure: "+e.message);
        start();
    });
});



if (forge.media) {

    asyncTest("Gallery Video Player", 1, function() {
        forge.file.getVideo({
            source: "gallery"
        }, function (file) {
            forge.file.URL(file, function (url) {
                forge.media.videoPlay(url, function () {
                    askQuestion("Did your video just play?", {
                        Yes: function () {
                            ok(true, "video capture successful");
                            start();
                        },
                        No: function () {
                            ok(false, "didn't play back just-captured video");
                            start();
                        }
                    });
                }, function (e) {
                    ok(false, "API call failure: "+e.message);
                    start();
                });
            }, function (e) {
                ok(false, "API call failure: "+e.message);
                start();
            });
        },	function (e) {
            ok(false, "API call failure: "+e.message);
            start();
        });
    });

}


asyncTest("Gallery", 5, function() {
    var runTest = function () {
        forge.file.getImage({
            source: "gallery",
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
                    forge.file.isFile(file, function (is) {
                        if (is) {
                            ok(true, "forge.file.isFile is true");
                        } else {
                            ok(false, "forge.file.isFile is false");
                        }
                        forge.file.URL(file, function (url) {
                            askQuestion("Is this your image:<br><img src='"+url+"' style='max-width: 100px; max-height: 100px'>", { Yes: function () {
                                ok(true, "Success with forge.file.URL");
                                forge.file.base64(file, function (data) {
                                    askQuestion("Is this also your image:<br><img src='data:image/jpg;base64,"+data+"' style='max-width: 100px; max-height: 100px'>", { Yes: function () {
                                        ok(true, "Success with forge.file.base64");
                                        start();
                                    }, No: function () {
                                        ok(false, "User claims failure with forge.file.base64");
                                        start();
                                    }});
                                }, function (e) {
                                    ok(false, "API call failure: "+e.message);
                                    start();
                                });
                            }, No: function () {
                                ok(false, "User claims failure with forge.file.URL");
                                start();
                            }});
                        }, function (e) {
                            ok(false, "API call failure: "+e.message);
                            start();
                        });
                    }, function (e) {
                        ok(false, "API call failure: "+e.message);
                        start();
                    });
                }, function (e) {
                    ok(false, "API call failure: "+e.message);
                    start();
                });

            }, No: function () {
                ok(false, "User claims failure");
                start();
            }});
        }, function (e) {
            ok(false, "API call failure: "+e.message);
            start();
        });
    };
    askQuestion("In this test use the gallery to select a picture when prompted", { Ok: runTest });
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
