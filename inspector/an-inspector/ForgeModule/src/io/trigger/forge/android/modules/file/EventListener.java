package io.trigger.forge.android.modules.file;

import android.os.Bundle;

import io.trigger.forge.android.core.ForgeApp;
import io.trigger.forge.android.core.ForgeEventListener;

public class EventListener extends ForgeEventListener {
	@Override
	public void onCreate(Bundle savedInstanceState) {
		// Check for Google Photos separately so that, if the device doesn't have a Google Photos permission, the user
		// isn't repeatedly asked for WRITE_EXTERNAL_STORAGE every time the app loads
		/*if (ContextCompat.checkSelfPermission(ForgeApp.getActivity(), "com.google.android.apps.photos.permission.GOOGLE_PHOTOS") != PackageManager.PERMISSION_GRANTED) {
			ActivityCompat.requestPermissions(ForgeApp.getActivity(), new String[] {
				"com.google.android.apps.photos.permission.GOOGLE_PHOTOS"
			}, PERMISSIONS_REQUEST);
		}*/

		// initialize i8n strings
		API.io_trigger_dialog_capture_camera_description = ForgeApp.getActivity().getString(R.string.io_trigger_dialog_capture_camera_description);
		API.io_trigger_dialog_capture_source_camera = ForgeApp.getActivity().getString(R.string.io_trigger_dialog_capture_source_camera);
		API.io_trigger_dialog_capture_source_gallery = ForgeApp.getActivity().getString(R.string.io_trigger_dialog_capture_source_gallery);
		API.io_trigger_dialog_capture_pick_source = ForgeApp.getActivity().getString(R.string.io_trigger_dialog_capture_pick_source);
	}
}