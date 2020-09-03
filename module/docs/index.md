``file``: File and Gallery access
=================================

The ``forge.file`` namespace allows storage of files on the local system and selection from the users saved photos and videos.


## File objects

File objects are simple JavaScript objects which can be serialised using JSON.stringify and safely stored in Forge preferences.

### Definition

A File object contains the following keys:

    {
        "endpoint": "/temporary",
        "resource": "23e4567-e89b-12d3-a456-426614174000.png",
    }

* `endpoint` represents one of the storage types exposed by the built-in webserver for use by your app.
* `resource` represents the (optional) path and filename of the resource available from the specified endpoint.

For more information see: [Core Types](/docs/current/api/core/types.html)

### Persistence

Unless explicitly saved to permanent storage, assume that all file objects are temporary.

>::Note:: For more information about how to cache remote files in your app, see [Caching files](/docs/current/recipes/offline/cache.html).


## Config options

usage_description
:   This key lets you describe the reason your app accesses the user's media gallery. When the system prompts the user to allow access, this string is displayed as part of the alert.


## API

### Media Pickers

!method: forge.file.getImage([params], success, error)
!param: params `object` an optional object of parameters
!param: success `function(file)` callback to be invoked when no errors occur (argument is the returned file)
!description: Returns a file object for a image selected by the user from their photo gallery.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

The optional parameters can contain any combination of the following:

-  ``width``  (number): The maximum height of the image returned.
-  ``height`` (number): The maximum width of the image returned.
-  ``fixRotation`` (boolean): Checks the image's EXIF metadata and correctly rotate the image if needed.

Returned files are stored in a temporary location and may be deleted by the device operating system. Use `forge.file.saveURL` if you need to save the file to a permanent location.

!method: forge.file.getVideo([params], success, error)
!param: params `object` an optional object of parameters
!param: success `function(file)` callback to be invoked when no errors occur (argument is the returned file)
!description: Returns a file object for a video selected by the user from their media gallery.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

The optional parameters can contain any combination of the following:

- ``videoQuality``: Sets the returned video's quality. Valid options are: `"default"`, `"low"`, "`medium`" and `"high"`.  (iOS only)

Returned files are stored in a temporary location and may be deleted by the device operating system. Use `forge.file.saveURL` if you need to save the file to a permanent location.

Please note that it is hard to predict the quantifiable properties of videos that have been transcoded with the `videoQuality` setting as it can vary greatly between operating system and device versions. Generally the `"high"` setting corresponds to the highest-quality video recording supported for device content sources.


### Operations on Paths

!method: forge.file.getLocal(path, success, error)
!description: Deprecated in favour of `forge.file.getFileFromSourceDirectory`

!method: forge.file.getFileFromSourceDirectory(path, success, error)
!param: path `string` path to the file, e.g. "images/home.png".
!param: success `function(file)` callback to be invoked when no errors occur (argument is the returned file)
!description: Returns a file object for a file included in the `src` folder of your app.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur


### Operations on File objects

!method: forge.file.URL(file, success, error)
!description: Deprecated in favour of `forge.file.getScriptURL`

!method: forge.file.getScriptURL(file, success, error)
!param: file `file` the file object to load data from
!param: success `function(url)` callback to be invoked when no errors occur (argument is the file URL)
!description: Returns a URL which can be used to access the content via Javascript or Web View.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

!method: forge.file.isFile(file, success, error)
!description: Deprecated in favour of `forge.file.exists`

!method: forge.file.exists(file, success, error)
!param: file `file` the file object to check
!param: success `function(exists)` callback to be invoked when no errors occur (argument is a boolean value)
!description: Returns true or false based on whether a given object is a file object and points to an existing file on the current device.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

!method: forge.file.info(file, success, error)
!param: file `file` the file object to get information for
!param: success `function(object)` callback to be invoked when no errors occur
!description: Returns information about the given file. Supported attributes: `size`, `date`, `mimetype`
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

!method: forge.file.base64(file, success, error)
!param: file `file` the file object to load data from
!param: success `function(base64String)` callback to be invoked when no errors occur
!description: Returns the base64 value for a file's content.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

!method: forge.file.string(file, success, error)
!param: file `file` the file object to load data from
!param: success `function(string)` callback to be invoked when no errors occur
!description: Returns the string value for a file's content.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

!method: forge.file.remove(file, success, error)
!param: file `file` the file object to delete
!param: success `function(string)` callback to be invoked when no errors occur
!description: Delete a file from the local filesystem, will work for cached files but not images stored in the users photo gallery.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

### Operations on URLs

!method: forge.file.cacheURL(url, success, error)
!param: url `string` URL of file to cache
!param: success `function(file)` callback to be invoked when no errors occur (argument is the returned file)
!description: Downloads a file at a specified URL and returns a file object which can be used for later access. Useful for caching remote resources such as images which can then be accessed directly from the local filesystem at a later date.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

Cached files may be removed at any time by the operating system, and it
is highly recommended you use the [forge.file.isFile](index.html#forgefileisfilefile-success-error) method to check a cached
file is still available before using it.

!method: forge.file.saveURL(url, success, error)
!param: url `string` URL of file to cache
!param: success `function(file)` callback to be invoked when no errors occur (argument is the returned file)
!description: Downloads a file at a specified URL and returns a file object which can be used for later access. Saves the file in a permanant location rather than in a cache location as with [forge.file.cacheURL](index.html#forgefilecacheurlurl-success-error).
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

> ::Important:: Files downloaded via this method will not be removed if you do not
remove them, if the file is only going to be used temporarily then
[forge.file.cacheURL](index.html#forgefilecacheurlurl-success-error) is more appropriate.


### Operations on Filesystem

!method: forge.file.clearCache(success, error)
!param: success `function(string)` callback to be invoked when no errors occur
!description: Deletes all files currently saved in the local cache.
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

!method: forge.file.getStorageInformation(success, error)
!description: Deprecated in favour of `forge.file.getStorageSizeInformation`

!method: forge.file.getStorageSizeInformation(success, error)
!param: success `function(object)` callback to be invoked when no errors occur
!description: Returns device storage information. Supported attributes: `total`, `free`, `app`, `endpoints`
!platforms: iOS, Android
!param: error `function(content)` called with details of any error which may occur

The returned information contains the following keys:

* `total`: The total storage space of the device in bytes.
* `free`: The amount of free storage space available on the device in bytes.
* `app`: The amount of storage space used by the app in bytes.
* `endpoints`: The amount of storage space used by the app's endpoints in bytes.

To get the size in other units, you can simply divide the return values by:

* Kilobytes: 1024
* Megabytes: Math.pow(1024, 2)
* Gigabytes: Math.pow(1024, 3)


## Permissions

On Android this module will add the ``WRITE_EXTERNAL_STORAGE``
permission to your app, users will be prompted to accept this when they
install your app.
