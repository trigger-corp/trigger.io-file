package io.trigger.forge.android.modules.file;

import static android.app.Activity.RESULT_CANCELED;
import static android.app.Activity.RESULT_OK;
import io.trigger.forge.android.core.ForgeApp;
import io.trigger.forge.android.core.ForgeFile;
import io.trigger.forge.android.core.ForgeIntentResultHandler;
import io.trigger.forge.android.core.ForgeParam;
import io.trigger.forge.android.core.ForgeTask;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.TimeZone;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import android.app.AlertDialog;
import android.content.ContentValues;
import android.content.DialogInterface;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.provider.MediaStore.Images.ImageColumns;
import android.provider.MediaStore.MediaColumns;
import android.util.Base64;

import com.google.gson.JsonObject;

public class API {
	public static void getImage(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		task.performAsync(new Runnable() {
			@Override
			public void run() {
				final DialogInterface.OnClickListener clickListener = new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int item) {
						Intent intent;
						ForgeIntentResultHandler handler = null;
						switch (item) {
						case 0:
							intent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
							// define the file-name to save photo taken by Camera
							// activity
							String fileName = String.valueOf(new java.util.Date().getTime()) + ".jpg";
							// create parameters for Intent with filename
							Uri imageUri = null;
							String tmpReturnUri = null;
							if (task.params.has("saveLocation") && task.params.get("saveLocation").getAsString().equals("file")) {
								java.io.File dir = null;
								if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.FROYO) {
									dir = ForgeApp.getActivity().getExternalFilesDir(Environment.DIRECTORY_PICTURES);
								}
								if (dir == null) {
									dir = Environment.getExternalStorageDirectory();
									dir = new java.io.File(dir, "Android/data/" + ForgeApp.getActivity().getApplicationContext().getPackageName() + "/files/");
								}
								dir.mkdirs();
								java.io.File file = new java.io.File(dir, fileName);
								imageUri = Uri.fromFile(file);
								tmpReturnUri = imageUri.toString();
							} else {
								ContentValues values = new ContentValues();
								values.put(MediaColumns.TITLE, fileName);
								values.put(ImageColumns.DESCRIPTION, "Image capture by camera");
								values.put(MediaColumns.MIME_TYPE, "image/jpeg");
								imageUri = ForgeApp.getActivity().getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
								tmpReturnUri = imageUri.toString();
							}

							final String returnUri = tmpReturnUri;
							intent.putExtra(MediaStore.EXTRA_OUTPUT, imageUri);

							handler = new ForgeIntentResultHandler() {
								@Override
								public void result(int requestCode, int resultCode, Intent data) {
									if (resultCode == RESULT_OK) {
										task.success(returnUri);
									} else if (resultCode == RESULT_CANCELED) {
										task.error("User cancelled image capture", "EXPECTED_FAILURE", null);
									} else {
										task.error("Unknown error capturing image", "UNEXPECTED_FAILURE", null);
									}
								}
							};
							break;
						case 1:
						default:
							intent = new Intent(Intent.ACTION_PICK);
							intent.setType("image/*");

							handler = new ForgeIntentResultHandler() {
								@Override
								public void result(int requestCode, int resultCode, Intent data) {
									if (resultCode == RESULT_OK) {
										task.success(API.fixImageUri(data.getData()).toString());
									} else if (resultCode == RESULT_CANCELED) {
										task.error("User cancelled image capture", "EXPECTED_FAILURE", null);
									} else {
										task.error("Unknown error capturing image", "UNEXPECTED_FAILURE", null);
									}
								}
							};
							break;
						}
						ForgeApp.intentWithHandler(intent, handler);
					}
				};

				final DialogInterface.OnCancelListener cancelListener = new DialogInterface.OnCancelListener() {
					@Override
					public void onCancel(DialogInterface dialog) {
						task.error("User cancelled image capture", "EXPECTED_FAILURE", null);
					}
				};

				if (task.params.has("source") && task.params.get("source").getAsString().equals("camera")) {
					clickListener.onClick(null, 0);
				} else if (task.params.has("source") && task.params.get("source").getAsString().equals("gallery")) {
					clickListener.onClick(null, 1);
				} else {
					task.performUI(new Runnable() {
						@Override
						public void run() {
							final CharSequence[] items = { "Camera", "Gallery" };
							AlertDialog.Builder builder = new AlertDialog.Builder(ForgeApp.getActivity());
							builder.setTitle("Pick a source");
							builder.setItems(items, clickListener);
							builder.setCancelable(true);
							builder.setOnCancelListener(cancelListener);
							AlertDialog alert = builder.create();
							alert.show();
						}
					});
				}

			}
		});
	}

	public static void getVideo(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		task.performUI(new Runnable() {

			@Override
			public void run() {
				final DialogInterface.OnClickListener clickListener = new DialogInterface.OnClickListener() {
					public void onClick(DialogInterface dialog, int item) {
						Intent intent;
						ForgeIntentResultHandler handler = null;
						switch (item) {
						case 0:
							intent = new Intent(MediaStore.ACTION_VIDEO_CAPTURE);
							intent.putExtra(MediaStore.EXTRA_VIDEO_QUALITY, 1);

							if (task.params.has("videoDuration")) {
								intent.putExtra(MediaStore.EXTRA_DURATION_LIMIT, task.params.get("videoDuration").getAsInt());
							}

							handler = new ForgeIntentResultHandler() {
								@Override
								public void result(int requestCode, int resultCode, Intent data) {
									if (resultCode == RESULT_OK) {
										if (data.getData() == null) {
											if (Build.VERSION.SDK_INT >= 18) {
												// Bug in Nexus 4.3 devices (maybe other 4.3 devices so try this trick on all 4.3 devices that return null)
												// https://code.google.com/p/android/issues/detail?id=57996
												long max_val = 0;
												Cursor cursor = ForgeApp.getActivity().getContentResolver().query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, new String[] { "MAX(_id) as max_id" }, null, null, "_id");
												if (cursor.moveToFirst()) {
													max_val = cursor.getLong(cursor.getColumnIndex("max_id"));
													task.success(MediaStore.Video.Media.EXTERNAL_CONTENT_URI.toString()+"/"+max_val);
													return;
												}
											} else {
												task.error("Unknown error capturing video", "UNEXPECTED_FAILURE", null);
											}
										} else {
											task.success(data.getData().toString());
										}
									} else if (resultCode == RESULT_CANCELED) {
										task.error("User cancelled video capture", "EXPECTED_FAILURE", null);
									} else {
										task.error("Unknown error capturing video", "UNEXPECTED_FAILURE", null);
									}
								}
							};
							break;
						case 1:
						default:
							intent = new Intent(Intent.ACTION_PICK);
							intent.setType("video/*");

							handler = new ForgeIntentResultHandler() {
								@Override
								public void result(int requestCode, int resultCode, Intent data) {
									if (resultCode == RESULT_OK) {
										task.success(data.toUri(0));
									} else if (resultCode == RESULT_CANCELED) {
										task.error("User cancelled video capture", "EXPECTED_FAILURE", null);
									} else {
										task.error("Unknown error capturing video", "UNEXPECTED_FAILURE", null);
									}
								}
							};
							break;
						}
						ForgeApp.intentWithHandler(intent, handler);
					}
				};

				if (task.params.has("source") && task.params.get("source").getAsString().equals("camera")) {
					clickListener.onClick(null, 0);
				} else if (task.params.has("source") && task.params.get("source").getAsString().equals("gallery")) {
					clickListener.onClick(null, 1);
				} else {
					task.performUI(new Runnable() {
						@Override
						public void run() {
							final CharSequence[] items = { "Camera", "Gallery" };
							AlertDialog.Builder builder = new AlertDialog.Builder(ForgeApp.getActivity());
							builder.setTitle("Pick a source");
							builder.setItems(items, clickListener);
							builder.setCancelable(false);
							AlertDialog alert = builder.create();
							alert.show();
						}
					});
				}
			}
		});
	}

	public static void getLocal(final ForgeTask task, @ForgeParam("name") String name) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		task.success(new ForgeFile(ForgeApp.getActivity(), name).toJSON());
	}

	public static void isFile(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		task.success(new ForgeFile(ForgeApp.getActivity(), task.params).exists());
	}

	public static void base64(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		if (!task.params.has("uri") || task.params.get("uri").isJsonNull()) {
			task.error("Invalid parameters sent to forge.file.base64", "BAD_INPUT", null);
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

	public static void string(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		if (!task.params.has("uri") || task.params.get("uri").isJsonNull()) {
			task.error("Invalid parameters sent to forge.file.string", "BAD_INPUT", null);
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

	public static void info(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		if (!task.params.has("uri") || task.params.get("uri").isJsonNull()) {
			task.error("Invalid parameters sent to forge.file.metadata", "BAD_INPUT", null);
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
							String[] projection = { MediaStore.MediaColumns.DATE_ADDED };
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
					task.error(e.getMessage(), "UNEXPECTED_FAILURE", null);
				}
			}
		});
	}

	public static void URL(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		task.success(new ForgeFile(ForgeApp.getActivity(), task.params).url());
	}

	public static void cacheURL(final ForgeTask task, @ForgeParam("url") final String url) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
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

	public static void saveURL(final ForgeTask task, @ForgeParam("url") final String url) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
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

	public static void remove(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		if (new ForgeFile(ForgeApp.getActivity(), task.params).remove()) {
			task.success();
		} else {
			task.error("File could not be deleted", "UNEXPECTED_FAILURE", null);
		}
	}

	public static void clearCache(final ForgeTask task) {
		if (!EventListener.checkPermissions()) {
			task.error("Permission denied", "UNEXPECTED_FAILURE", null);
			return;
		}
		for (java.io.File file : ForgeApp.getActivity().getCacheDir().listFiles()) {
			file.delete();
		}
		task.success();
	}
	
	/**
	 * Workaround for the various bugs introduced by Google Photos
	 * 
	 * Converts Uri's in the form:
	 *     content://com.google.android.apps.photos.contentprovider/-1/1/content%3A%2F%2Fmedia%2Fexternal%2Fimages%2Fmedia%2F107/ACTUAL/740661381
	 * To:  
	 *     content://media/external/images/media/107
	 *     
	 * @param uri
	 * @return
	 */
	private static Uri fixImageUri(Uri uri) {
		Pattern pattern = Pattern.compile("(?=content://media.*\\d)(.*)(?=/ACTUAL/.*\\d)");
	    if (uri.getPath().contains("content")) {
	        Matcher matcher = pattern.matcher(uri.getPath());
	        if (matcher.find()) {
	            return Uri.parse(matcher.group(1));
	        } else {
	        	return uri;
	        }
	    } else {
	        return uri;
	    }
	}
}
