/* global forge */

forge["file"] = {
    /**
     * Allow the user to select an image and give a file object representing it.
     *
     * @param {Object} props
     * @param {function({uri: string, name: string})=} success
     * @param {function({message: string}=} error
     */
    "getImage": function (props, success, error) {
        if (typeof props === "function") {
            error = success;
            success = props;
            props = {};
        }
        if (!props) {
            props = {};
        }
        forge.internal.call("file.getImage", props, success && function (uri) {
            var file = {
                uri: uri,
                name: "Image",
                type: "image"
            };
            if (props.width) {
                file.width = props.width;
            }
            if (props.height) {
                file.height = props.height;
            }
            success(file);
        }, error);
    },

    /**
     * Allow the user to select a video and give a file object representing it.
     *
     * @param {Object} props
     * @param {function({uri: string, name: string})=} success
     * @param {function({message: string}=} error
     */
    "getVideo": function (props, success, error) {
        if (typeof props === "function") {
            error = success;
            success = props;
            props = {};
        }
        if (!props) {
            props = {};
        }
        forge.internal.call("file.getVideo", props, success && function (uri) {
            var file = {
                uri: uri,
                name: "Video",
                type: "video"
            };
            success(file);
        }, error);
    },

    /**
     * Get file object for a local file.
     *
     * @param {string} name
     * @param {function(string)=} success
     * @param {function({message: string}=} error
     */
    "getLocal": function (path, success, error) {
        forge.internal.call("file.getLocal", {name: path}, success, error);
    },

    /**
     * Returns file information
     *
     * @param {{uri: string, name: string}} file
     * @param {function(object)=} success
     * @param {function({message: string}=} error
     */
    "info": function (file, success, error) {
        forge.internal.call("file.info", file, success, error);
    },

    /**
     * Get the base64 value for a files contents.
     *
     * @param {{uri: string, name: string}} file
     * @param {function(string)=} success
     * @param {function({message: string}=} error
     */
    "base64": function (file, success, error) {
        forge.internal.call("file.base64", file, success, error);
    },

    /**
     * Get the string value for a files contents.
     *
     * @param {{uri: string, name: string}} file
     * @param {function(string)=} success
     * @param {function({message: string}=} error
     */
    "string": function (file, success, error) {
        forge.internal.call("file.string", file, success, error);
    },

    /**
     * Get the URL an image which is no bigger than the given height and width.
     *
     * URL must be useable in the current scope of the code, may return a base64 data: URI.
     *
     * @param {{uri: string, name: string}} file
     * @param {Object} props
     * @param {function(string)=} success
     * @param {function({message: string}=} error
     */
    "URL": function (file, props, success, error) {
        if (typeof props === "function") {
            error = success;
            success = props;
        }
        // Avoid mutating original file
        var newFile = {};
        for (var prop in file) {
            newFile[prop] = file[prop];
        }
        newFile.height = props.height || file.height || undefined;
        newFile.width = props.width || file.width || undefined;
        forge.internal.call("file.URL", newFile, success, error);
    },

    /**
     * Check a file object represents a file which exists.
     *
     * @param {{uri: string, name: string}} file
     * @param {function(boolean)=} success
     * @param {function({message: string}=} error
     */
    "isFile": function (file, success, error) {
        if (!file || !("uri" in file)) {
            success(false);
        } else {
            forge.internal.call("file.isFile", file, success, error);
        }
    },

    /**
     * Download and save a URL, return the file object representing saved file.
     *
     * @param {string} URL
     * @param {function({uri: string})=} success
     * @param {function({message: string}=} error
     */
    "cacheURL": function (url, success, error) {
        forge.internal.call("file.cacheURL", { url: url }, success && function (uri) {
            success({
                uri: uri
            });
        }, error);
    },
    "saveURL": function (url, success, error) {
        forge.internal.call("file.saveURL", { url: url }, success && function (uri) {
            success({
                uri: uri
            });
        }, error);
    },

    /**
     * Delete a file.
     *
     * @param {{uri: string} file
     * @param {function()=} success
     * @param {function({message: string}=} error
     */
    "remove": function (file, success, error) {
        forge.internal.call("file.remove", file, success, error);
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
    "getStorageInformation": function (success, error) {
        forge.internal.call("file.getStorageInformation", {}, success, error);
    }
};
