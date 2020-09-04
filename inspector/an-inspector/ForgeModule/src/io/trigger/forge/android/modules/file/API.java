package io.trigger.forge.android.modules.file;

import android.Manifest;
import android.content.Intent;
import android.net.Uri;
import android.util.Base64;

import com.google.gson.JsonObject;

import java.io.File;
import java.io.IOException;

import io.trigger.forge.android.core.ForgeActivity.EventAccessBlock;
import io.trigger.forge.android.core.ForgeApp;
import io.trigger.forge.android.core.ForgeFile;
import io.trigger.forge.android.core.ForgeIntentResultHandler;
import io.trigger.forge.android.core.ForgeParam;
import io.trigger.forge.android.core.ForgeStorage;
import io.trigger.forge.android.core.ForgeTask;

import static android.app.Activity.RESULT_CANCELED;
import static android.app.Activity.RESULT_OK;

public class API {

    //region media picker

    public static void getImage(final ForgeTask task) { // deprecated in favour of pickMedia
        API.pickMedia(task, "image/*");
    }

    public static void getVideo(final ForgeTask task) { // deprecated in favour of pickMedia
        API.pickMedia(task, "video/*");
    }

    public static void pickMedia(final ForgeTask task, final String type) {
        // parse options
        final int maxWidth = task.params.has("width") ? task.params.get("width").getAsInt() : 0;
        final int maxHeight = task.params.has("height") ? task.params.get("height").getAsInt() : 0;
        final String videoQuality = task.params.has("videoQuality") ? task.params.get("videoQuality").getAsString() : "default";

        ForgeIntentResultHandler resultHandler = new ForgeIntentResultHandler() {
            @Override
            public void result(int requestCode, int resultCode, Intent data) {
                if (resultCode == RESULT_OK) {

                    /* TODO if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN) {
                        int itemCount = data.getClipData().getItemCount();
                        for (int index = 0; index < itemCount; index++) {
                            Uri uri = data.getClipData().getItemAt(index).getUri();
                            ForgeLog.d(uri.toString());
                        }
                    }*/

                    Uri source = data.getData();
                    try {
                        ForgeFile forgeFile = null;
                        if (type.startsWith("image/") && (maxWidth > 0 || maxHeight > 0)) {
                            forgeFile = Storage.writeImageUriToTemporaryFile(source, maxWidth, maxHeight);

                        } else if (type.startsWith("video/") && !videoQuality.equalsIgnoreCase("default")) {
                            forgeFile = Storage.writeVideoUriToTemporaryFile(source, videoQuality);

                        } else {
                            forgeFile = Storage.writeMediaUriToTemporaryFile(source);
                        }

                        task.success(forgeFile.toScriptObject());

                    } catch (IOException e) {
                        e.printStackTrace();
                        task.error("Error saving image to app storage: " + e.getLocalizedMessage(), "EXPECTED_FAILURE", null);
                    }
                } else if (resultCode == RESULT_CANCELED) {
                    task.error("User cancelled image capture", "EXPECTED_FAILURE", null);
                } else {
                    task.error("Unknown error capturing image", "UNEXPECTED_FAILURE", null);
                }
            }
        };

        ForgeApp.getActivity().requestPermission("com.google.android.apps.photos.permission.GOOGLE_PHOTOS", new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                // ignore 'granted' as not all devices have this permission and we can't check if they do
                task.withPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new Runnable() {
                    @Override
                    public void run() {
                        Intent intent = new Intent(Intent.ACTION_PICK);
                        intent.setType(type);
                        // TODO intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                        ForgeApp.intentWithHandler(intent, resultHandler);
                    }
                });
            }
        });
    }

    //endregion media picker


    //region operations on resource paths

    /**
     * Used to be called getLocal, returns a file to a path pointing at a resource in the source directory
     * @param task
     * @param resource A path to an asset in the app's src directory like: path/to/local/resource.html
     * @return A File like: { endpoint: "/src", resource: "/path/to/local/resource.html" }
     */
    public static void getFileFromSourceDirectory(final ForgeTask task, @ForgeParam("resource") final String resource) {
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                ForgeFile forgeFile = new ForgeFile(ForgeStorage.EndpointId.Source, resource);
                task.success(forgeFile.toScriptObject());
            }
        });
    }

    /**
     * Returns a url to a path pointing at a resource in the source directory
     * @param task
     * @param resource A path to an asset in the app's src directory like: path/to/local/resource.html
     * @return A fully qualified url like: https://localhost:1234/src/path/to/local/resource.html
     */
    public static void getURLFromSourceDirectory(final ForgeTask task, @ForgeParam("resource") final String resource) {
        if (resource.startsWith("http://") || resource.startsWith("https://")) {
            task.success(resource);
        }
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                ForgeFile forgeFile = new ForgeFile(ForgeStorage.EndpointId.Source, resource);
                task.success(ForgeStorage.getScriptURL(forgeFile).toString());
            }
        });
    }

    //endregion operations on resource paths


    //region operations on File objects

    /**
     *
     * @param task
     * @param file a File like { endpoint: "/temporary", resource: "/path/to/resource.html" }
     * @return an absolute path like: /endpoint/with/path/to/resource.html
     */
    public static void getScriptPath(final ForgeTask task, @ForgeParam("file") final JsonObject file) {
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                ForgeFile forgeFile = new ForgeFile(file);
                task.success(ForgeStorage.getScriptPath(forgeFile).toString());
            }
        });
    }

    /**
     * used to be called URL
     * @param task
     * @param file a File like { endpoint: "/temporary", resource: "/path/to/resource.html" }
     * @return an absolute URL like: https://localhost:1234/tmp/path/to/resource.html
     */
    public static void getScriptURL(final ForgeTask task, @ForgeParam("file") final JsonObject file) {
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                ForgeFile forgeFile = new ForgeFile(file);
                task.success(ForgeStorage.getScriptURL(forgeFile).toString());
            }
        });
    }

    public static void exists(final ForgeTask task, @ForgeParam("file") final JsonObject file) {
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                ForgeFile forgeFile = new ForgeFile(file);
                task.success(forgeFile.exists());
            }
        });
    }

    public static void info(final ForgeTask task, @ForgeParam("file") final JsonObject file) {
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                task.performAsync(new Runnable() {
                    public void run() {
                        ForgeFile forgeFile = new ForgeFile(file);
                        JsonObject result = null;
                        try {
                            result = forgeFile.getAttributes();
                        } catch (IOException e) {
                            e.printStackTrace();
                            task.error("Error reading file: " + file.toString(), "EXPECTED_FAILURE", null);
                            return;
                        }
                        task.success(result);
                    }
                });
            }
        });
    }

    public static void base64(final ForgeTask task, @ForgeParam("file") final JsonObject file) {
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                task.performAsync(new Runnable() {
                    public void run() {
                        ForgeFile forgeFile = new ForgeFile(file);
                        try {
                            String base64 = Base64.encodeToString(forgeFile.getContents(), Base64.NO_WRAP);
                            task.success(base64);
                        } catch (IOException e) {
                            e.printStackTrace();
                            task.error("Error reading file: " + file.toString(), "EXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }

    public static void string(final ForgeTask task, @ForgeParam("file") final JsonObject file) {
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                task.performAsync(new Runnable() {
                    public void run() {
                        ForgeFile forgeFile = new ForgeFile(file);
                        try {
                            String string = new String(forgeFile.getContents());
                            task.success(string);
                        } catch (IOException e) {
                            e.printStackTrace();
                            task.error("Error reading file: " + file.toString(), "EXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }

    public static void remove(final ForgeTask task, @ForgeParam("file") final JsonObject file) {
        task.withPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                ForgeFile forgeFile = new ForgeFile(file);
                try {
                    task.success(forgeFile.remove());
                } catch (IOException e) {
                    e.printStackTrace();
                    task.error("Error removing file: " + file.toString(), "EXPECTED_FAILURE", null);
                }
            }
        });
    }

    //endregion operations on File objects


    //region operations on urls

    public static void cacheURL(final ForgeTask task, @ForgeParam("url") final String url) {
        task.withPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                try {
                    ForgeFile forgeFile = Storage.writeURLToEndpoint(url, ForgeStorage.EndpointId.Temporary);
                    task.success(forgeFile.toScriptObject());
                } catch (IOException e) {
                    e.printStackTrace();
                    task.error("Unable to cache url: " + url);
                }
            }
        });
    }

    public static void saveURL(final ForgeTask task, @ForgeParam("url") final String url) {
        task.withPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                try {
                    ForgeFile forgeFile = Storage.writeURLToEndpoint(url, ForgeStorage.EndpointId.Permanent);
                    task.success(forgeFile.toScriptObject());
                } catch (IOException e) {
                    e.printStackTrace();
                    task.error("Unable to write url: " + url);
                }
            }
        });
    }

    //endregion operations on urls


    //region operations on filesystem

    public static void clearCache(final ForgeTask task) {
        task.withPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                File temporaryDirectory = new File(ForgeStorage.Directories.Temporary().getPath());
                for (File file : temporaryDirectory.listFiles()) {
                    file.delete();
                }
                task.success();
            }
        });
    }

    public static void getStorageSizeInformation(final ForgeTask task) {
        task.withPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new Runnable() {
            @Override
            public void run() {
                task.performAsync(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            JsonObject result = ForgeStorage.getSizeInformation();
                            task.success(result);
                        } catch (IOException e) {
                            task.error("Error reading storage size information: " + e.getLocalizedMessage(), "UNEXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }

    //endregion operations on filesystem
}
