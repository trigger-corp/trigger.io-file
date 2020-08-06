package io.trigger.forge.android.modules.file;

import static android.app.Activity.RESULT_CANCELED;
import static android.app.Activity.RESULT_OK;

import io.trigger.forge.android.core.ForgeActivity.EventAccessBlock;
import io.trigger.forge.android.core.ForgeApp;
import io.trigger.forge.android.core.ForgeFile;
import io.trigger.forge.android.core.ForgeIntentResultHandler;
import io.trigger.forge.android.core.ForgeParam;
import io.trigger.forge.android.core.ForgeTask;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.channels.FileChannel;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Stack;
import java.util.TimeZone;
import java.util.UUID;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;

import com.google.gson.JsonObject;

public class API {

    public static void getImage(final ForgeTask task) {
        final Runnable gallery = new Runnable() {
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
                                    task.success(ForgeFile.fixImageUri(uri).toString());
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
                gallery.run();
            }
        });
    }

    public static void getVideo(final ForgeTask task) {
        final Runnable gallery = new Runnable() {
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
                gallery.run();
            }
        });

    }

    public static void getLocal(final ForgeTask task, @ForgeParam("name") final String name) {
        ForgeApp.getActivity().requestPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.success(new ForgeFile(ForgeApp.getActivity(), name).toJSON());
            }
        });
    }

    public static void isFile(final ForgeTask task) {
        ForgeApp.getActivity().requestPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.success(new ForgeFile(ForgeApp.getActivity(), task.params).exists());
            }
        });
    }

    public static void base64(final ForgeTask task) {
        if (!task.params.has("uri") || task.params.get("uri").isJsonNull()) {
            task.error("Invalid parameters sent to forge.file.base64", "BAD_INPUT", null);
            return;
        }

        ForgeApp.getActivity().requestPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.performAsync(new Runnable() {
                    public void run() {
                        try {
                            task.success(Base64.encodeToString(new ForgeFile(ForgeApp.getActivity(), task.params).data(), Base64.NO_WRAP));
                        } catch (Exception e) {
                            task.error("Error reading file", "UNEXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }

    public static void string(final ForgeTask task) {
        if (!task.params.has("uri") || task.params.get("uri").isJsonNull()) {
            task.error("Invalid parameters sent to forge.file.string", "BAD_INPUT", null);
            return;
        }
        ForgeApp.getActivity().requestPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.performAsync(new Runnable() {
                    public void run() {
                        try {
                            task.success(new String(new ForgeFile(ForgeApp.getActivity(), task.params).data()));
                        } catch (Exception e) {
                            task.error("Error reading file", "UNEXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }

    public static void info(final ForgeTask task) {
        if (!task.params.has("uri") || task.params.get("uri").isJsonNull()) {
            task.error("Invalid parameters sent to forge.file.info. Please make sure you're passing a 'file' object.", "BAD_INPUT", null);
            return;
        }
        ForgeApp.getActivity().requestPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.performAsync(new Runnable() {
                    public void run() {
                        try {
                            Uri uri = Uri.parse(task.params.get("uri").getAsString());
                            long size = ForgeFile.assetForUri(ForgeApp.getActivity(), uri).getLength();
                            long time = 0;
                            if (uri.getScheme().equals("content")) {
                                Cursor cursor = null;
                                try {
                                    String[] projection = {MediaStore.MediaColumns.DATE_ADDED};
                                    cursor = ForgeApp.getActivity().getContentResolver().query(uri, projection, null, null, null);
                                    if (cursor.moveToFirst()) {
                                        time = cursor.getLong(0) * 1000;
                                    }
                                } catch (Exception e) {
                                } finally {
                                    if (cursor != null) {
                                        cursor.close();
                                    }
                                }
                            } else {
                                time = (new File(uri.getPath())).lastModified();
                            }
                            SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
                            df.setTimeZone(TimeZone.getTimeZone("UTC"));
                            JsonObject result = new JsonObject();
                            result.addProperty("size", size);
                            result.addProperty("date", df.format(new Date(time)));
                            task.success(result);
                        } catch (Exception e) {
                            task.error("File not found: " + task.params.get("uri").getAsString(), "EXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }

    public static void URL(final ForgeTask task) {
        ForgeApp.getActivity().requestPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.success(new ForgeFile(ForgeApp.getActivity(), task.params).url());
            }
        });
    }

    public static void cacheURL(final ForgeTask task, @ForgeParam("url") final String url) {
        ForgeApp.getActivity().requestPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.performUI(new Runnable() {
                    @Override
                    public void run() {
                        final java.io.File tempFile = new java.io.File(ForgeApp.getActivity().getCacheDir(), UUID.randomUUID().toString());
                        try {
                            tempFile.createNewFile();
                            task.performAsync(new Runnable() {
                                public void run() {
                                    try {
                                        java.net.URL parsedUrl = new java.net.URL(url);
                                        InputStream input = parsedUrl.openStream();
                                        try {
                                            OutputStream output = new FileOutputStream(tempFile);
                                            try {
                                                byte[] buffer = new byte[1024];
                                                int bytesRead = 0;
                                                while ((bytesRead = input.read(buffer, 0, buffer.length)) >= 0) {
                                                    output.write(buffer, 0, bytesRead);
                                                }
                                                task.success("file://" + tempFile.getAbsolutePath());
                                            } finally {
                                                output.close();
                                            }
                                        } finally {
                                            input.close();
                                        }
                                    } catch (IOException e) {
                                        task.error("Error creating file", "UNEXPECTED_FAILURE", null);
                                    }
                                }
                            });
                        } catch (IOException e) {
                            task.error("Error creating file", "UNEXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }

    public static void saveURL(final ForgeTask task, @ForgeParam("url") final String url) {
        ForgeApp.getActivity().requestPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.performUI(new Runnable() {
                    public void run() {
                        String fileName = UUID.randomUUID().toString();
                        java.io.File dir = null;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.FROYO) {
                            dir = ForgeApp.getActivity().getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS);
                        }
                        if (dir == null) {
                            dir = Environment.getExternalStorageDirectory();
                            dir = new java.io.File(dir, "Android/data/" + ForgeApp.getActivity().getApplicationContext().getPackageName() + "/files/");
                        }
                        final java.io.File saveFile = new java.io.File(dir, fileName);

                        try {
                            saveFile.createNewFile();

                            task.performAsync(new Runnable() {

                                @Override
                                public void run() {
                                    try {
                                        java.net.URL parsedUrl = new java.net.URL(url);
                                        InputStream input = parsedUrl.openStream();
                                        try {
                                            OutputStream output = new FileOutputStream(saveFile);
                                            try {
                                                byte[] buffer = new byte[1024];
                                                int bytesRead = 0;
                                                while ((bytesRead = input.read(buffer, 0, buffer.length)) >= 0) {
                                                    output.write(buffer, 0, bytesRead);
                                                }
                                                task.success("file://" + saveFile.getAbsolutePath());
                                            } finally {
                                                output.close();
                                            }
                                        } finally {
                                            input.close();
                                        }
                                    } catch (IOException e) {

                                    }
                                }
                            });
                        } catch (IOException e) {
                            task.error("Error creating file", "UNEXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }

    public static void remove(final ForgeTask task) {
        ForgeApp.getActivity().requestPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                if (new ForgeFile(ForgeApp.getActivity(), task.params).remove()) {
                    task.success();
                } else {
                    task.error("File could not be deleted", "UNEXPECTED_FAILURE", null);
                }
            }
        });
    }

    public static void clearCache(final ForgeTask task) {
        ForgeApp.getActivity().requestPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                for (java.io.File file : ForgeApp.getActivity().getCacheDir().listFiles()) {
                    file.delete();
                }
                task.success();
            }
        });
    }

    public static void getStorageInformation(final ForgeTask task) {
        ForgeApp.getActivity().requestPermission(Manifest.permission.READ_EXTERNAL_STORAGE, new EventAccessBlock() {
            @Override
            public void run(boolean granted) {
                if (!granted) {
                    task.error("Permission denied. User didn't grant access to storage.", "EXPECTED_FAILURE", null);
                    return;
                }
                task.performAsync(new Runnable() {
                    public void run() {
                        try {
                            PackageManager pm = ForgeApp.getActivity().getPackageManager();
                            String dirName = pm.getPackageInfo(ForgeApp.getActivity().getPackageName(), 0).applicationInfo.dataDir;
                            File dataDir = new File(dirName);
                            File cacheDir = ForgeApp.getActivity().getCacheDir();

                            JsonObject result = new JsonObject();
                            result.addProperty("total", dataDir.getTotalSpace());
                            result.addProperty("free", dataDir.getUsableSpace());
                            result.addProperty("app", getDirectorySize(dataDir));
                            result.addProperty("cache", getDirectorySize(cacheDir));
                            task.success(result);

                        } catch (Exception e) {
                            task.error("Error reading storage information", "UNEXPECTED_FAILURE", null);
                        }
                    }
                });
            }
        });
    }


    /**
     * Calculate physical size of directory in bytes
     *
     * @param path
     * @return
     */
    private static long getDirectorySize(File path) {
        long result = 0;

        Stack<File> dirs= new Stack<File>();
        dirs.clear();
        dirs.push(path);

        while(!dirs.isEmpty()) {
            File current = dirs.pop();
            File[] files = current.listFiles();
            for(File file: files){
                if (file.isDirectory()) {
                    dirs.push(file);
                } else {
                    result += file.length();
                }
            }
        }

        return result;
    }


}
