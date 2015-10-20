package io.trigger.forge.android.modules.file;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import io.trigger.forge.android.core.ForgeApp;
import io.trigger.forge.android.core.ForgeEventListener;

public class EventListener extends ForgeEventListener {

	static final int PERMISSIONS_REQUEST = 1;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		
		if (ContextCompat.checkSelfPermission(ForgeApp.getActivity(), Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
			ActivityCompat.requestPermissions(ForgeApp.getActivity(), new String[] {  
				Manifest.permission.WRITE_EXTERNAL_STORAGE
			}, PERMISSIONS_REQUEST);
		}
		
		// Check for Google Photos separately so that, if the device doesn't have a Google Photos permission, the user
		// isn't repeatedly asked for WRITE_EXTERNAL_STORAGE every time the app loads
		if (ContextCompat.checkSelfPermission(ForgeApp.getActivity(), "com.google.android.apps.photos.permission.GOOGLE_PHOTOS") != PackageManager.PERMISSION_GRANTED) {
			ActivityCompat.requestPermissions(ForgeApp.getActivity(), new String[] {
				"com.google.android.apps.photos.permission.GOOGLE_PHOTOS"
			}, PERMISSIONS_REQUEST);
		}
	}
	
	public static boolean checkPermissions() {
		// Don't check for Google Photos, as some devices oddly don't have that permission
		return ContextCompat.checkSelfPermission(ForgeApp.getActivity(), Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
	}
}