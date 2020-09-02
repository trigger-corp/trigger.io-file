package io.trigger.forge.android.modules.file;

import android.Manifest;
import android.content.Intent;
import android.net.Uri;
import android.util.Base64;

import com.google.gson.JsonObject;
import com.llamalab.safs.Paths;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.nio.channels.FileChannel;
import java.text.SimpleDateFormat;
import java.util.Date;

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

    public static void getImage(final ForgeTask task) {
        final Runnable picker = new Runnable() {
            @Override
            public void run() {
                ForgeApp.getActivity().requestPermission("com.google.android.apps.photos.permission.GOOGLE_PHOTOS", new EventAccessBlock() {
                    @Override
                    public void run(boolean granted) {
                        // TODO ignore 'granted' as not all devices have this permission and there does not seem to be a way to check for it
                        Intent intent = new Intent(Intent.ACTION_PICK);
                        intent.setType("image/*");
                        ForgeIntentResultHandler handler = new ForgeIntentResultHandler() {
                            @Override
                            public void result(int requestCode, int resultCode, Intent data) {
                                if (resultCode == RESULT_OK) {
                                    Uri uri = data.getData();
                                    // save it & return it
                                    // TODO task.success(ForgeFile.fixImageUri(uri).toString());
                                } else if (resultCode == RESULT_CANCELED) {
                                    task.error("User cancelled image capture", "EXPECTED_FAILURE", null);
                                } else {
                                    task.error("Unknown error capturing image", "UNEXPECTED_FAILURE", null);
                                }
                            }
                        };
                        ForgeApp.intentWithHandler(intent, handler);
                    }
                });
            }
        };

        ForgeApp.getActivity().requestPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                picker.run();
            }
        });
    }

    public static void getVideo(final ForgeTask task) {
        final Runnable picker = new Runnable() {
            @Override
            public void run() {
                ForgeApp.getActivity().requestPermission("com.google.android.apps.photos.permission.GOOGLE_PHOTOS", new EventAccessBlock() {
                    @Override
                    public void run(boolean granted) {
                        // TODO ignore 'granted' as not all devices have this permission and there does not seem to be a way to check for it
                        Intent intent = new Intent(Intent.ACTION_PICK);
                        intent.setType("video/*");
                        ForgeIntentResultHandler handler = new ForgeIntentResultHandler() {
                            @Override
                            public void result(int requestCode, int resultCode, Intent data) {
                                if (resultCode == RESULT_OK) {
                                    // check if we need to transcode the video
                                    String videoQuality = task.params.has("videoQuality") ? task.params.get("videoQuality").getAsString() : "default";
                                    if (!videoQuality.equalsIgnoreCase("default")) {
                                        // TODO transcode video once min API level hits 18 and we can rely on MediaCodec being present
                                    }

                                    Uri uri = data.getData();
                                    if (!uri.toString().startsWith("content://com.google.android.apps.photos.contentprovider")) {
                                        task.success(data.toUri(0));
                                        return;
                                    }

                                    // If this file comes from Google Photos we to need to cache it locally
                                    // as Marshmallow's braindead permissions model won't let it be used
                                    // by external intents.
                                    String filename = "temp_forge_file_video_" + (new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date()));
                                    File output = null;
                                    try {
                                        output = File.createTempFile(filename, "mp4");
                                        FileInputStream input = (FileInputStream) ForgeApp.getActivity().getContentResolver().openInputStream(uri);
                                        FileChannel src = input.getChannel();
                                        FileChannel dst = new FileOutputStream(output).getChannel();
                                        dst.transferFrom(src, 0, src.size());
                                        src.close();
                                        dst.close();
                                        task.success(Uri.fromFile(output).toString());
                                    } catch (IOException e) {
                                        task.error("Error retrieving video: " + e.getLocalizedMessage(), "UNEXPECTED_FAILURE", null);
                                    }
                                } else if (resultCode == RESULT_CANCELED) {
                                    task.error("User cancelled video capture", "EXPECTED_FAILURE", null);
                                } else {
                                    task.error("Unknown error capturing video", "UNEXPECTED_FAILURE", null);
                                }
                            }
                        };
                        ForgeApp.intentWithHandler(intent, handler);
                    }
                });
            }
        };

        ForgeApp.getActivity().requestPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                picker.run();
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
                    ForgeFile forgeFile = API.writeURL(url, ForgeStorage.EndpointId.Temporary);
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
                    ForgeFile forgeFile = API.writeURL(url, ForgeStorage.EndpointId.Permanent);
                    task.success(forgeFile.toScriptObject());
                } catch (IOException e) {
                    e.printStackTrace();
                    task.error("Unable to write url: " + url);
                }
            }
        });
    }

    private static ForgeFile writeURL(final String url, ForgeStorage.EndpointId endpointId) throws IOException {
        Uri source = Uri.parse(url);

        String filename = ForgeStorage.temporaryFileNameWithExtension(source.getLastPathSegment());
        ForgeFile forgeFile = new ForgeFile(endpointId, filename);
        File destination = Paths.get(ForgeStorage.getNativeURL(forgeFile).getPath()).toFile();

        InputStream inputStream = new URL(source.toString()).openStream();
        try {
            OutputStream outputStream = new FileOutputStream(destination);
            try {
                byte[] buffer = new byte[1024];
                int bytesRead = 0;
                while ((bytesRead = inputStream.read(buffer, 0, buffer.length)) >= 0) {
                    outputStream.write(buffer, 0, bytesRead);
                }
            } finally {
                outputStream.close();
            }
        } finally {
            inputStream.close();
        }

        return forgeFile;
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
