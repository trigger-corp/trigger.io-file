/* global forge */

forge["file"] = {
    /**
     * Allow the user to select an image and give a file object representing it.
     *
     * @param {{width: number, height: number}} options
     * @param {function(file: File)=} success
     * @param {function({message: string}=} error
     */
    "getImage": function (options, success, error) {
        if (typeof options === "function") {
            error = success;
            success = options;
            options = {};
        }
        if (!options) {
            options = {};
        }
        options.source = "gallery";
        forge.internal.call("file.getImage", options, success && function (file) {
            success(file);
        }, error);
    },

    /**
     * Allow the user to select a video and give a file object representing it.
     *
     * @param {{"quality": string}} options
     * @param {function(file: File)=} success
     * @param {function({message: string}=} error
     */
    "getVideo": function (options, success, error) {
        if (typeof options === "function") {
            error = success;
            success = options;
            options = {};
        }
        if (!options) {
            options = {};
        }
        options.source = "gallery";
        forge.internal.call("file.getVideo", options, success && function (file) {
            success(file);
        }, error);
    },

    /**
     * Get file object for a local resource in your app's src/ directory.
     *
     * @param {string} resource
     * @param {function(file: File)=} success
     * @param {function({message: string}=} error
     */
    "getLocal": function (resource, success, error) { // deprecated
        forge.internal.call("file.getFileFromSourceDirectory", {
            resource: resource
        }, success, error);
    },
    "getFileFromSourceDirectory": function (resource, success, error) {
        forge.internal.call("file.getFileFromSourceDirectory", {
            resource: resource
        }, success, error);
    },

    /**
     * Get the URL an image which is no bigger than the given height and width.
     *
     * URL must be useable in the current scope of the code, may return a base64 data: URI.
     *
     * @param {file: File} file
     * @param {object} options TODO deprecate
     * @param {function(url: string)=} success
     * @param {function({message: string}=} error
     */
    // TODO either deprecate this or rename it to something like getEmbeddableImageURL
    "URL": function (file, options, success, error) { // deprecated
        if (typeof options === "function") {
            error = success;
            success = options;
        }
        // TODO deprecated update docs Avoid mutating original file
        var newFile = {};
        for (var prop in file) {
            newFile[prop] = file[prop];
        }
        newFile.height = options.height || file.height || undefined;
        newFile.width = options.width || file.width || undefined;
        forge.internal.call("file.getScriptURL", {
            file: newFile
        }, function (url) {
            success(url);
        }, error);
    },
    "getScriptURL": function (file, success, error) {
        forge.internal.call("file.getScriptURL", {
            file: file
        }, function (url) {
            success(url);
        }, error);
    },

    /**
     * Returns file information
     *
     * @param {file: File} file
     * @param {function(object)=} success
     * @param {function({message: string}=} error
     */
    "info": function (file, success, error) {
        forge.internal.call("file.info", {
            file: file
        }, success, error);
    },

    /**
     * Get the base64 value for a files contents.
     *
     * @param {file: File} file
     * @param {function(base64: string)=} success
     * @param {function({message: string}=} error
     */
    "base64": function (file, success, error) {
        forge.internal.call("file.base64", {
            file: file
        }, success, error);
    },

    /**
     * Get the string value for a files contents.
     *
     * @param {file: File} file
     * @param {function(contents: string)=} success
     * @param {function({message: string}=} error
     */
    "string": function (file, success, error) {
        forge.internal.call("file.string", {
            file: file
        }, success, error);
    },

    /**
     * Check a file object represents a file which exists.
     *
     * @param {file: File} file
     * @param {function(boolean)=} success
     * @param {function({message: string}=} error
     */
    "isFile": function (file, success, error) { // deprecated
        if (!file) {
            success(false);
        } else {
            forge.internal.call("file.exists", {
                file: file
            }, success, error);
        }
    },
    "exists": function (file, success, error) {
        if (!file) {
            success(false);
        } else {
            forge.internal.call("file.exists", {
                file: file
            }, success, error);
        }
    },

    /**
     * Delete a file.
     *
     * @param {file: File} file
     * @param {function()=} success
     * @param {function({message: string}=} error
     */
    "remove": function (file, success, error) {
        forge.internal.call("file.remove", {
            file: file
        }, success, error);
    },


    /**
     * Download and cache a URL, return the file object representing cached file.
     *
     * @param {string} URL
     * @param {function(file: File)=} success
     * @param {function({message: string}=} error
     */
    "cacheURL": function (url, success, error) {
        forge.internal.call("file.cacheURL", {
            url: url
        }, success && function (file) {
            success(file);
        }, error);
    },

    /**
     * Download and save a URL, return the file object representing saved file.
     *
     * @param {string} URL
     * @param {function(file: File)=} success
     * @param {function({message: string}=} error
     */
    "saveURL": function (url, success, error) {
        forge.internal.call("file.saveURL", {
            url: url
        }, success && function (file) {
            success(file);
        }, error);
    },


    /**
     * Delete all cached files
     *
     * @param {function()=} success
     * @param {function({message: string}=} error
     */
    "clearCache": function (success, error) {
        forge.internal.call("file.clearCache", {}, success, error);
    },

    /**
     * Retrieve device storage information
     *
     * @param {function()=} success
     * @param {function({total: number, free: number, app: number, cache: number})=} success
     */
    "getStorageInformation": function (success, error) { // deprecated
        forge.internal.call("file.getStorageSizeInformation", {}, success, error);
    },
    "getStorageSizeInformation": function (success, error) {
        forge.internal.call("file.getStorageSizeInformation", {}, success, error);
    }
};
