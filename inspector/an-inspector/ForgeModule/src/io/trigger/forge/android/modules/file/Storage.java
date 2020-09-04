package io.trigger.forge.android.modules.file;

import android.content.ContentResolver;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Matrix;
import android.net.Uri;
import android.webkit.MimeTypeMap;

import com.drew.imaging.ImageMetadataReader;
import com.drew.imaging.ImageProcessingException;
import com.drew.metadata.Metadata;
import com.drew.metadata.MetadataException;
import com.drew.metadata.exif.ExifIFD0Directory;
import com.llamalab.safs.Paths;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URL;
import java.nio.channels.FileChannel;

import io.trigger.forge.android.core.ForgeApp;
import io.trigger.forge.android.core.ForgeFile;
import io.trigger.forge.android.core.ForgeLog;
import io.trigger.forge.android.core.ForgeStorage;
import io.trigger.forge.android.util.BitmapUtil;

public class Storage {

    public static ForgeFile writeURLToEndpoint(final String url, ForgeStorage.EndpointId endpointId) throws IOException {
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


    public static ForgeFile writeMediaUriToTemporaryFile(Uri source) throws IOException {
        ContentResolver contentResolver = ForgeApp.getActivity().getContentResolver();

        String extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(contentResolver.getType(source));
        String filename = ForgeStorage.temporaryFileNameWithExtension(extension);
        ForgeFile forgeFile = new ForgeFile(ForgeStorage.EndpointId.Temporary, filename);
        File destination = Paths.get(ForgeStorage.getNativeURL(forgeFile).getPath()).toFile();

        FileInputStream inputStream = (FileInputStream)contentResolver.openInputStream(source);
        FileChannel sourceChannel = inputStream.getChannel();
        FileChannel destinationChannel = new FileOutputStream(destination).getChannel();
        destinationChannel.transferFrom(sourceChannel, 0, sourceChannel.size());
        sourceChannel.close();
        destinationChannel.close();

        return forgeFile;
    }


    public static ForgeFile writeImageUriToTemporaryFile(Uri source, boolean fixRotation, int maxWidth, int maxHeight) throws IOException {
        ContentResolver contentResolver = ForgeApp.getActivity().getContentResolver();

        String filename = ForgeStorage.temporaryFileNameWithExtension("jpg");
        ForgeFile forgeFile = new ForgeFile(ForgeStorage.EndpointId.Temporary, filename);
        File destination = Paths.get(ForgeStorage.getNativeURL(forgeFile).getPath()).toFile();

        // read source metadata
        Metadata metadata = null;
        try {
            BufferedInputStream inputStream = new BufferedInputStream(contentResolver.openInputStream(source));
            metadata = ImageMetadataReader.readMetadata(inputStream, false);
            if (metadata == null) {
                throw new IOException("Failed to obtain metadata for image with uri: " + source.toString());
            }
        } catch (ImageProcessingException e) {
            throw new IOException(e.getLocalizedMessage());
        }

        // fix source rotation - TODO optional?
        int rotation = 0;
        ExifIFD0Directory exifIFD0Directory = metadata.getDirectory(ExifIFD0Directory.class);
        if (exifIFD0Directory == null) {
            ForgeLog.w("No Exif data included in image with uri: " + source.toString());
        } else {
            try {
                switch (exifIFD0Directory.getInt(ExifIFD0Directory.TAG_ORIENTATION)) {
                    case 1:	 rotation = 0;   break;
                    case 3:  rotation = 180; break;
                    case 6:  rotation = 90;  break;
                    case 8:  rotation = 270; break;
                    default: rotation = 0;   break;
                }
            } catch (MetadataException e) {
                ForgeLog.w("Failed to extract Exif data from image with uri: " + source.toString());
            }
            ForgeLog.d("Setting rotation from Exif data: " + rotation + " degrees");
        }

        // create an in-memory bitmap object from source uri and resize
        Context context = ForgeApp.getActivity();
        Bitmap bitmap = BitmapUtil.bitmapFromUri(context, source);
        Matrix matrix = BitmapUtil.matrixForBitmap(context, bitmap, maxWidth, maxHeight, rotation);
        if (matrix == null) {
            return Storage.writeMediaUriToTemporaryFile(source); // fallback to saving the original image
        }
        bitmap = BitmapUtil.applyMatrix(context, bitmap, matrix);
        if (bitmap == null) {
            return Storage.writeMediaUriToTemporaryFile(source); // fallback to saving the original image
        }

        // save in-memory bitmap
        FileOutputStream outputStream = new FileOutputStream(destination);
        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, outputStream);
        outputStream.close();

        // release bitmap memory
        bitmap.recycle();

        return forgeFile;
    }

    public static ForgeFile writeVideoUriToTemporaryFile(Uri source, String videoQuality) throws IOException {
        // TODO transcode video once min API level hits 18 and we can rely on MediaCodec being present
        return Storage.writeMediaUriToTemporaryFile(source);
    }

}
