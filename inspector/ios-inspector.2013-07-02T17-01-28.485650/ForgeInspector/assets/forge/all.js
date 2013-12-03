/*! Copyright 2011 Trigger Corp. All rights reserved. */
// Start function wrapper to create local scope.
(function () {

// Things we want to expose
var forge = {};

// Things we want to only use internally
var internal = {};
forge.config = window.forge.config;/*
 * Platform independent API.
 */

// Event listeners
internal.listeners = {};

// Store callbacks in this
var temporaryAsyncStorage = {};

// All of this is to queue commands if waiting for Catalyst
var callQueue = [];
var callQueueTimeout = null;
var handlingQueue = false;
var handleCallQueue = function () {
	if (callQueue.length > 0) {
		if (!internal.debug || window.catalystConnected) {
			handlingQueue = true;
			while (callQueue.length > 0) {
				var call = callQueue.shift();
				if (call[0] == "logging.log") {
					console.log(call[1].message);
				}
				internal.priv.call.apply(internal.priv, call);
			}
			handlingQueue = false;
		} else {
			callQueueTimeout = setTimeout(handleCallQueue, 500);
		}
	}
};

// Internal methods to handle communication between privileged and non-privileged code
internal.priv = {
	/**
	 * Generic wrapper for native API calls.
	 *
	 * @param {string} method Name of the API method.
	 * @param {*} params Key-values to pass to privileged code.
	 * @param {function(...[*])} success Called if native method is successful.
	 * @param {function({message: string}=} error
	 */
	call: function (method, params, success, error) {
		if ((!internal.debug || window.catalystConnected || method === "internal.showDebugWarning") && (callQueue.length == 0 || handlingQueue)) {
			var callid = forge.tools.UUID();
			var onetime = true;
			// API Methods which can be calledback multiple times
			if (method === "button.onClicked.addListener" || method === "message.toFocussed") {
				onetime = false;
			}
			if (success || error) {
				temporaryAsyncStorage[callid] = {
					success: success,
					error: error,
					onetime: onetime
				};
			}
			var call = {
				callid: callid,
				method: method,
				params: params
			};
			internal.priv.send(call);
			if (window._forgeDebug) {
				try {
					call.start = (new Date().getTime()) / 1000.0;
					window._forgeDebug.forge.APICall.apiRequest(call);
				} catch (e) {}
			}
		} else {
			callQueue.push(arguments);
			if (!callQueueTimeout) {
				callQueueTimeout = setTimeout(handleCallQueue, 500);
			}
		}
	},

	/**
	 * Calls native code from JS
	 * @param {*} data Object to send to privileged/native code.
	 */
	send: function (data) {
		// Implemented in platform specific code
		throw new Error("Forge error: missing bridge to privileged code");
	},

	/**
	 * Called from native at the end of asynchronous tasks.
	 *
	 * @param {Object} result Object containing result details
	 */
	receive: function (result) {
		if (result.callid) {
			// Handle a response
			if (typeof temporaryAsyncStorage[result.callid] === undefined) {
				forge.log("Nothing stored for call ID: " + result.callid);
			}

			var callbacks = temporaryAsyncStorage[result.callid];
			
			var returnValue = (typeof result.content === "undefined" ? null : result.content);
			
			if (callbacks && callbacks[result.status]) {
				callbacks[result.status](result.content);
			}
			if (callbacks && callbacks.onetime) {
				// Remove used callbacks
				delete temporaryAsyncStorage[result.callid];
			}
			if (window._forgeDebug) {
				try {
					result.end = (new Date().getTime()) / 1000.0;
					window._forgeDebug.forge.APICall.apiResponse(result);
				} catch (e) {}
			}
		} else if (result.event) {
			// Handle an event
			if (internal.listeners[result.event]) {
				internal.listeners[result.event].forEach(function (callback) {
					if (result.params) {
						callback(result.params);
					} else {
						callback();
					}
				})
			}
			if (internal.listeners['*']) {
				internal.listeners['*'].forEach(function (callback) {
					if (result.params) {
						callback(result.event, result.params);
					} else {
						callback(result.event);
					}
				})
			}
			if (window._forgeDebug) {
				try {
					result.start = (new Date().getTime()) / 1000.0;
					window._forgeDebug.forge.APICall.apiEvent(result);
				} catch (e) {}
			}
		}
	}	
};

internal.addEventListener = function (event, callback) {
	if (internal.listeners[event]) {
		internal.listeners[event].push(callback);
	} else {
		internal.listeners[event] = [callback];
	}
}

/**
 * Generate query string
 */
internal.generateQueryString = function (obj) {
	if (!obj) {
		return "";
	}
	if (!(obj instanceof Object)) {
		return new String(obj).toString();
	}
	
	var params = [];
	var processObj = function (obj, scope) {
		if (obj === null) {
			return;
		} else if (obj instanceof Array) {
			var index = 0;
			for (var x in obj) {
				var key = (scope ? scope : '') + '[' + index + ']';
				index += 1;
				if (!obj.hasOwnProperty(x)) continue;
				processObj(obj[x], key);
			}
		} else if (obj instanceof Object) {
			for (var x in obj) {
				if (!obj.hasOwnProperty(x)) continue;
				var key = x;
				if (scope) {
					key = scope + '[' + x + ']';
				}
				processObj(obj[x], key);
			}
		} else {
			params.push(encodeURIComponent(scope)+'='+encodeURIComponent(obj));
		}
	};
	processObj(obj);
	return params.join('&').replace('%20', '+');
};

/**
 * Generate multipart form string
 */
internal.generateMultipartString = function (obj, boundary) {
	if (typeof obj === "string") {
		return '';
	}
	var partQuery = '';
	for (var key in obj) {
		if (!obj.hasOwnProperty(key)) continue;
		if (obj[key] === null) continue;
		// TODO: recursive flatten, deal with arrays
		partQuery += '--'+boundary+'\r\n';
		partQuery += 'Content-Disposition: form-data; name="'+key.replace('"', '\\"')+'"\r\n\r\n';
		partQuery += obj[key].toString()+'\r\n'
	}
	return partQuery;
};

/**
 * Generate a URI from an existing url and additional query data
 */
internal.generateURI = function (uri, queryData) {
	var newQuery = '';
	if (uri.indexOf('?') !== -1) {
		newQuery += uri.split('?')[1]+'&';
		uri = uri.split('?')[0];
	}
	newQuery += this.generateQueryString(queryData)+'&';
	// Remove trailing &
	newQuery = newQuery.substring(0,newQuery.length-1);
	return uri+(newQuery ? '?'+newQuery : '');
};

/**
 * Call a callback with an error that a module is disabled
 */
internal.disabledModule = function (cb, module) {
	var message = "The '"+module+"' module is disabled for this app, enable it in your app config and rebuild in order to use this function";
	forge.logging.error(message);
	cb && cb({
		message: message,
		type: "UNAVAILABLE",
		subtype: "DISABLED_MODULE"
	});
}

// Method to enable debug mode
forge.enableDebug = function () {
	internal.debug = true;
	internal.priv.call("internal.showDebugWarning", {}, null, null);
	internal.priv.call("internal.hideDebugWarning", {}, null, null);
};
// Check the old debug method isn't being used
setTimeout(function () {
	if (window.forge && window.forge.debug) {
		alert("Warning!\n\n'forge.debug = true;' is no longer supported\n\nUse 'forge.enableDebug();' instead.")
	}
}, 3000);
forge['is'] = {
	/**
	 * @return {boolean}
	 */
	'mobile': function() {
		return false;
	},
	/**
	 * @return {boolean}
	 */
	'desktop': function() {
		return false;
	},
	/**
	 * @return {boolean}
	 */
	'android': function() {
		return false;
	},
	/**
	 * @return {boolean}
	 */
	'ios': function() {
		return false;
	},
	/**
	 * @return {boolean}
	 */
	'chrome': function() {
		return false;
	},
	/**
	 * @return {boolean}
	 */
	'firefox': function() {
		return false;
	},
	/**
	 * @return {boolean}
	 */
	'safari': function() {
		return false;
	},
	/**
	 * @return {boolean}
	 */
	'ie': function() {
		return false;
	},
	/**
	 * @return {boolean}
	 */
	'web': function() {
		return false;
	},
	'orientation': {
		'portrait': function () {
			return false;
		},
		'landscape': function () {
			return false;
		}
	},
	'connection': {
		'connected': function () {
			return true;
		},
		'wifi': function () {
			return true;
		}
	}
};forge['is']['mobile'] = function() {
	return true;
};

forge['is']['ios'] = function() {
	return true;
};

forge['is']['orientation']['portrait'] = function () {
	return internal.currentOrientation == 'portrait';
};

forge['is']['orientation']['landscape'] = function () {
	return internal.currentOrientation == 'landscape';
};

forge['is']['connection']['connected'] = function () {
	return internal.currentConnectionState.connected;
};

forge['is']['connection']['wifi'] = function () {
	return internal.currentConnectionState.wifi;
};
//
// Logging helper functions
//

// Adapted from node.js
var inspectObject = function (obj, showHidden, depth) {
 	var seen = [];
 	stylize = function (str, styleType) {
 		return str;
 	};

 	function isRegExp(re) {
 		return re instanceof RegExp || (typeof re === 'object' && Object.prototype.toString.call(re) === '[object RegExp]');
 	}

 	function isArray(ar) {
 		return ar instanceof Array || Array.isArray(ar) || (ar && ar !== Object.prototype && isArray(ar.__proto__));
 	}

 	function isDate(d) {
 		if (d instanceof Date) return true;
 		if (typeof d !== 'object') return false;
 		var properties = Date.prototype && Object.getOwnPropertyNames(Date.prototype);
 		var proto = d.__proto__ && Object.getOwnPropertyNames(d.__proto__);
 		return JSON.stringify(proto) === JSON.stringify(properties);
 	}

 	function format(value, recurseTimes) {
 		try {
 			// Provide a hook for user-specified inspect functions.
 			// Check that value is an object with an inspect function on
 			// it

 			// Filter out the util module, it's inspect function
 			// is special
 			if (value && typeof value.inspect === 'function' &&

 			// Also filter out any prototype objects using the
 			// circular check.
 			!(value.constructor && value.constructor.prototype === value)) {
 				return value.inspect(recurseTimes);
 			}
 			// Primitive types cannot have properties
 			switch (typeof value) {
 			case 'undefined':
 				return stylize('undefined', 'undefined');
 			case 'string':
 				var simple = '\'' + JSON.stringify(value).replace(/^"|"$/g, '').replace(/'/g, "\\'").replace(/\\"/g, '"') + '\'';
 				return stylize(simple, 'string');
 			case 'number':
 				return stylize('' + value, 'number');
 			case 'boolean':
 				return stylize('' + value, 'boolean');
 			}
 			// For some reason typeof null is "object", so special case
 			// here.
 			if (value === null) {
 				return stylize('null', 'null');
 			}
 			// Special case Document
 			if (value instanceof Document) {
 				return (new XMLSerializer()).serializeToString(value);
 			}
 			// Look up the keys of the object.
 			var visible_keys = Object.keys(value);
 			var keys = showHidden ? Object.getOwnPropertyNames(value) : visible_keys;
 			// Functions without properties can be shortcutted.
 			if (typeof value === 'function' && keys.length === 0) {
 				var name = value.name ? ': ' + value.name : '';
 				return stylize('[Function' + name + ']', 'special');
 			}
 			// RegExp without properties can be shortcutted
 			if (isRegExp(value) && keys.length === 0) {
 				return stylize('' + value, 'regexp');
 			}
 			// Dates without properties can be shortcutted
 			if (isDate(value) && keys.length === 0) {
 				return stylize(value.toUTCString(), 'date');
 			}
 			var base, type, braces;
 			// Determine the object type
 			if (isArray(value)) {
 				type = 'Array';
 				braces = ['[', ']'];
 			} else {
 				type = 'Object';
 				braces = ['{', '}'];
 			}
 			// Make functions say that they are functions
 			if (typeof value === 'function') {
 				var n = value.name ? ': ' + value.name : '';
 				base = ' [Function' + n + ']';
 			} else {
 				base = '';
 			}
 			// Make RegExps say that they are RegExps
 			if (isRegExp(value)) {
 				base = ' ' + value;
 			}
 			// Make dates with properties first say the date
 			if (isDate(value)) {
 				base = ' ' + value.toUTCString();
 			}
 			if (keys.length === 0) {
 				return braces[0] + base + braces[1];
 			}
 			if (recurseTimes < 0) {
 				if (isRegExp(value)) {
 					return stylize('' + value, 'regexp');
 				} else {
 					return stylize('[Object]', 'special');
 				}
 			}
 			seen.push(value);
 			var output = keys.map(function (key) {
 				var name, str;
 				if (value.__lookupGetter__) {
 					if (value.__lookupGetter__(key)) {
 						if (value.__lookupSetter__(key)) {
 							str = stylize('[Getter/Setter]', 'special');
 						} else {
 							str = stylize('[Getter]', 'special');
 						}
 					} else {
 						if (value.__lookupSetter__(key)) {
 							str = stylize('[Setter]', 'special');
 						}
 					}
 				}
 				if (visible_keys.indexOf(key) < 0) {
 					name = '[' + key + ']';
 				}
 				if (!str) {
 					if (seen.indexOf(value[key]) < 0) {
 						if (recurseTimes === null) {
 							str = format(value[key]);
 						} else {
 							str = format(value[key], recurseTimes - 1);
 						}
 						if (str.indexOf('\n') > -1) {
 							if (isArray(value)) {
 								str = str.split('\n').map(

 								function (line) {
 									return '  ' + line;
 								}).join('\n').substr(2);
 							} else {
 								str = '\n' + str.split('\n').map(

 								function (
 								line) {
 									return '   ' + line;
 								}).join('\n');
 							}
 						}
 					} else {
 						str = stylize('[Circular]', 'special');
 					}
 				}
 				if (typeof name === 'undefined') {
 					if (type === 'Array' && key.match(/^\d+$/)) {
 						return str;
 					}
 					name = JSON.stringify('' + key);
 					if (name.match(/^"([a-zA-Z_][a-zA-Z_0-9]*)"$/)) {
 						name = name.substr(1, name.length - 2);
 						name = stylize(name, 'name');
 					} else {
 						name = name.replace(/'/g, "\\'").replace(/\\"/g, '"').replace(/(^"|"$)/g, "'");
 						name = stylize(name, 'string');
 					}
 				}
 				return name + ': ' + str;
 			});
 			seen.pop();
 			var numLinesEst = 0;
 			var length = output.reduce(function (prev, cur) {
 				numLinesEst++;
 				if (cur.indexOf('\n') >= 0) numLinesEst++;
 				return prev + cur.length + 1;
 			}, 0);
 			if (length > 50) {
 				output = braces[0] + (base === '' ? '' : base + '\n ') + ' ' + output.join(',\n  ') + ' ' + braces[1];
 			} else {
 				output = braces[0] + base + ' ' + output.join(', ') + ' ' + braces[1];
 			}
 			return output;
 		} catch (e) {
 			return '[No string representation]';
 		}
 	}
 	return format(obj, (typeof depth === 'undefined' ? 2 : depth));
};
var logMessage = function(message, level) {
	if ('logging' in forge.config) {
		var eyeCatcher = forge.config.logging.marker || 'FORGE';
	} else {
		var eyeCatcher = 'FORGE';
	}
	message = '[' + eyeCatcher + '] '
			+ (message.indexOf('\n') === -1 ? '' : '\n') + message;
	internal.priv.call("logging.log", {
		message: message,
		level: level
	});
	
	// Also log to the console if it exists.
	if (typeof console !== "undefined") {
		switch (level) {
			case 10:
				if (console.debug !== undefined && !(console.debug.toString && console.debug.toString().match('alert'))) {
					console.debug(message);
				}
				break;
			case 30:
				if (console.warn !== undefined && !(console.warn.toString && console.warn.toString().match('alert'))) {
					console.warn(message);
				}
				break;
			case 40:
			case 50:
				if (console.error !== undefined && !(console.error.toString && console.error.toString().match('alert'))) {
					console.error(message);
				}
				break;
			default:
			case 20:
				if (console.info !== undefined && !(console.info.toString && console.info.toString().match('alert'))) {
					console.info(message);
				}
				break;
		}
	}
};

var logNameToLevel = function(name, deflt) {
	if (name in forge.logging.LEVELS) {
		return forge.logging.LEVELS[name];
	} else {
		forge.logging.__logMessage('Unknown configured logging level: '+name);
		return deflt;
	}
};

var formatException = function(ex) {
	var exMsg = function(ex) {
		if (ex.message) {
			return ex.message;
		} else if (ex.description) {
			return ex.description;
		} else {
			return ''+ex;
		}
	}

	if (ex) {
		var str = '\nError: ' + exMsg(ex);
		try {
			if (ex.lineNumber) {
				str += ' on line number ' + ex.lineNumber;
			}
			if (ex.fileName) {
				var file = ex.fileName;
				str += ' in file ' + file.substr(file.lastIndexOf('/')+1);
			}
		} catch (e) {
		}
		if (ex.stack) {
			str += '\r\nStack trace:\r\n' + ex.stack;
		}
		return str;
	}
	return '';
};

forge['logging'] = {
	/**
	 * Log messages and exceptions to the console, if available
	 * @enum {number}
	 */
	LEVELS: {
		'ALL': 0,
		'DEBUG': 10,
		'INFO': 20,
		'WARNING': 30,
		'ERROR': 40,
		'CRITICAL': 50
	},

	'debug': function(message, exception) {
		forge.logging.log(message, exception, forge.logging.LEVELS.DEBUG);
	},
	'info': function(message, exception) {
		forge.logging.log(message, exception, forge.logging.LEVELS.INFO);
	},
	'warning': function(message, exception) {
		forge.logging.log(message, exception, forge.logging.LEVELS.WARNING);
	},
	'error': function(message, exception) {
		forge.logging.log(message, exception, forge.logging.LEVELS.ERROR);
	},
	'critical': function(message, exception) {
		forge.logging.log(message, exception, forge.logging.LEVELS.CRITICAL);
	},

	/**
	 * Log a message onto the console. An eyecatcher of [YOUR_UUID] will be automatically prepended.
	 * See the "logging.level" configuration directive, which controls how verbose the logging will be.
	 * @param {string} message the text you want to log
	 * @param {Error} exception (optional) an Error instance to log
	 * @param {number} level: one of "api.logging.DEBUG", "api.logging.INFO", "api.logging.WARNING", "api.logging.ERROR" or "api.logging.CRITICAL"
	 */
	'log': function(message, exception, level) {

		if (typeof(level) === 'undefined') {
			var level = forge.logging.LEVELS.INFO;
		}
		try {
			var confLevel = logNameToLevel(forge.config.logging.level, forge.logging.LEVELS.ALL);
		} catch(e) {
			var confLevel = forge.logging.LEVELS.ALL;
		}
		if (level >= confLevel) {
			logMessage(inspectObject(message, false, 10) + formatException(exception), level);
		}
	}
};forge['internal'] = {
	'ping': function (data, success, error) {
		internal.priv.call("internal.ping", {data: [data]}, success, error);
	},
	'call': internal.priv.call,
	'addEventListener': internal.addEventListener,
	listeners: internal.listeners
};var nullObj = {};
internal.currentOrientation = nullObj;
internal.currentConnectionState = nullObj;

// Internal orientation event
internal.addEventListener('internal.orientationChange', function (data) {
	if (internal.currentOrientation != data.orientation) {
		internal.currentOrientation = data.orientation;
		// Trigger public orientation event
		internal.priv.receive({
			event: 'event.orientationChange'
		});
	}
});

internal.addEventListener('internal.connectionStateChange', function (data) {
	if (data.connected != internal.currentConnectionState.connected || data.wifi != internal.currentConnectionState.wifi) {
		internal.currentConnectionState = data;
		internal.priv.receive({
			event: 'event.connectionStateChange'
		});
	}
});forge['event'] = {
	'menuPressed': {
		addListener: function (callback, error) {
			internal.addEventListener('event.menuPressed', callback);
		}
	},
	'backPressed': {
		addListener: function (callback, error) {
			internal.addEventListener('event.backPressed', function () {
				callback(function () {
					internal.priv.call('event.backPressed_closeApplication', {});
				});
			});
		},
		preventDefault: function (success, error) {
			internal.priv.call('event.backPressed_preventDefault', {}, success, error);
		},
		restoreDefault: function (success, error) {
			internal.priv.call('event.backPressed_restoreDefault', {}, success, error);
		}
	},
	'messagePushed': {
		addListener: function (callback, error) {
			internal.addEventListener('event.messagePushed', callback);
		}
	},
	'orientationChange': {
		addListener: function (callback, error) {
			internal.addEventListener('event.orientationChange', callback);
			
			if (nullObj && internal.currentOrientation !== nullObj) {
				internal.priv.receive({
					event: 'event.orientationChange'
				});
			}
		}
	},
	'connectionStateChange': {
		addListener: function (callback, error) {
			internal.addEventListener('event.connectionStateChange', callback);
			
			if (nullObj && internal.currentConnectionState !== nullObj) {
				internal.priv.receive({
					event: 'event.connectionStateChange'
				});
			}
		}
	},
	'appPaused': {
		addListener: function (callback, error) {
			internal.addEventListener('event.appPaused', callback);
		}
	},
	'appResumed': {
		addListener: function (callback, error) {
			internal.addEventListener('event.appResumed', callback);
		}
	}
};
forge['reload'] = {
	'updateAvailable': function(success, error) {
		internal.priv.call("reload.updateAvailable", {}, success, error);
	},
	'update': function(success, error) {
		internal.priv.call("reload.update", {}, success, error);
	},
	'pauseUpdate': function(success, error) {
		internal.priv.call("reload.pauseUpdate", {}, success, error);
	},
	'applyNow': function(success, error) {
		forge.logging.error("reload.applyNow has been disabled, please see docs.trigger.io for more information.");
		error({message: "reload.applyNow has been disabled, please see docs.trigger.io for more information.", type: "UNAVAILABLE"});
	},
	'applyAndRestartApp': function(success, error) {
		internal.priv.call("reload.applyAndRestartApp", {}, success, error);
	},
	'switchStream': function(streamid, success, error) {
		internal.priv.call("reload.switchStream", {streamid: streamid}, success, error);
	},
	'updateReady': {
		addListener: function (callback, error) {
			internal.addEventListener('reload.updateReady', callback);
		}
	},
	'updateProgress': {
		addListener: function (callback, error) {
			internal.addEventListener('reload.updateProgress', callback);
		}
	}
};
forge['tools'] = {
	/**
	 * Creates an RFC 4122 compliant UUID.
	 *
	 * http://www.rfc-archive.org/getrfc.php?rfc=4122
	 *
	 * @return {string} A new UUID.
	 */
	'UUID': function() {
		// Implemented in JS on all platforms. No point going to native for this.
		return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) {
			var r = Math.random() * 16 | 0;
			var v = c == "x" ? r : (r & 0x3 | 0x8);
			return v.toString(16);
		}).toUpperCase();
	},
	/**
	 * Resolve this name to a fully-qualified local or remote resource.
	 * The resource is not checked for existence.
	 * This method does not load the resource. For that, use "getPage()".
	 *
	 * For example, unqualified name: "my/resource.html"
	 * On Chrome: "chrome-extension://djggepjbfnnmhppnebibkbomfmnmkjln/my/resource.html"
	 * On Android: "file:///android_asset/my/resource.html"
	 *
	 * @param {string} resourceName Unqualified resource.
	 * @param {function(string)=} success Response data
	 * @param {function({message: string}=} error
	 */
	'getURL': function(resourceName, success, error) {
		internal.priv.call("tools.getURL", {
			name: resourceName.toString()
		}, success, error);
	}
};/*
 * iOS specific code
 */

var temporaryNativeQueueStorage = [];
var hasLoaded = false;

internal.priv.get = function () {
	var curData = JSON.stringify(temporaryNativeQueueStorage);
	temporaryNativeQueueStorage = [];
	return curData;
};

var timeouts = [],
	messageName = 'zero-timeout-message';

// Like setTimeout, but only takes a function argument.  There's
// no time argument (always zero) and no arguments (you have to
// use a closure).
function setZeroTimeoutPostMessage(fn) {
	timeouts.push(fn);
	window.postMessage(messageName, '*');
}

function setZeroTimeout(fn) {
	setTimeout(fn, 0);
}

function handleMessage(event) {
	if (event.source == window && event.data == messageName) {
		if (event.stopPropagation) {
			event.stopPropagation();
		}
		if (timeouts.length) {
			timeouts.shift()();
		}
	}
}

if (window.postMessage) {
	if (window.addEventListener) {
		window.addEventListener('message', handleMessage, true);
	} else if (window.attachEvent) {
		window.attachEvent('onmessage', handleMessage);
	}
	window.setZeroTimeout = setZeroTimeoutPostMessage;
} else {
	window.setZeroTimeout = setZeroTimeout;
}

internal.priv.send = function(data) {
	temporaryNativeQueueStorage.push(data);
	if (hasLoaded && !window.forge._flushing) {
		window.forge._flushing = true;
		setZeroTimeout(function () {
			window.location.href = "forge://go";
		});
	}
};

document.addEventListener("DOMContentLoaded", function () {
	hasLoaded = true;
	window.forge._flushing = true;
	setZeroTimeout(function () {
		window.location.href = "forge://go";
	});
}, false);

forge['_get'] = internal.priv.get;
forge['_receive'] = function () {
	var args = arguments;
	if (typeof window.setZeroTimeout === 'undefined') { // WP7 IE does not have setZeroTimeout
		setTimeout(function () { 
			internal.priv.receive.apply(this, args);
		}, 0);
	} else {
		setZeroTimeout(function () { 
			internal.priv.receive.apply(this, args);
		});
	}
};
// Expose our public API
window['forge'] = forge;	// Close variable scope from api-prefix.js
})();
(function () {
forge['file'] = {
	/**
	 * Allow the user to select an image and give a file object representing it.
	 *
	 * @param {Object} props
	 * @param {function({uri: string, name: string})=} success
	 * @param {function({message: string}=} error
	 */
	'getImage': function (props, success, error) {
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
				name: 'Image',
				type: 'image'
			};
			if (props.width) {
				file.width = props.width;
			}
			if (props.height) {
				file.height = props.height;
			}
			success(file)
		}, error);
	},
	/**
	 * Allow the user to select a video and give a file object representing it.
	 *
	 * @param {Object} props
	 * @param {function({uri: string, name: string})=} success
	 * @param {function({message: string}=} error
	 */
	'getVideo': function (props, success, error) {
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
				name: 'Video',
				type: 'video'
			};
			success(file)
		}, error);
	},
	/**
	 * Get file object for a local file.
	 *
	 * @param {string} name
	 * @param {function(string)=} success
	 * @param {function({message: string}=} error
	 */
	'getLocal': function (path, success, error) {
		forge.internal.call("file.getLocal", {name: path}, success, error);
	},
	/**
	 * Get the base64 value for a files contents.
	 *
	 * @param {{uri: string, name: string}} file
	 * @param {function(string)=} success
	 * @param {function({message: string}=} error
	 */
	'base64': function (file, success, error) {
		forge.internal.call("file.base64", file, success, error);
	},
	/**
	 * Get the string value for a files contents.
	 *
	 * @param {{uri: string, name: string}} file
	 * @param {function(string)=} success
	 * @param {function({message: string}=} error
	 */
	'string': function (file, success, error) {
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
	'URL': function (file, props, success, error) {
		if (typeof props === "function") {
			error = success;
			success = props;
		}
		// Avoid mutating original file
		var newFile = {}
		for (prop in file) {
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
	'isFile': function (file, success, error) {
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
	'cacheURL': function (url, success, error) {
		forge.internal.call("file.cacheURL",
			{url: url},
			success && function (uri) { success({uri: uri}) },
			error
		);
	},
	'saveURL': function (url, success, error) {
		forge.internal.call("file.saveURL",
			{url: url},
			success && function (uri) { success({uri: uri}) },
			error
		);
	},
	/**
	 * Delete a file.
	 *
	 * @param {{uri: string} file
	 * @param {function()=} success
	 * @param {function({message: string}=} error
	 */
	'remove': function (file, success, error) {
		forge.internal.call("file.remove", file, success, error);
	},
	/**
	 * Delete all cached files
	 *
	 * @param {function()=} success
	 * @param {function({message: string}=} error
	 */
	'clearCache': function (success, error) {
		forge.internal.call("file.clearCache", {}, success, error);
	}
};
})();