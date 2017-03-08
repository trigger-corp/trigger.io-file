/* global forge, module, asyncTest, equal, start, ok */
module("forge.file");

asyncTest("Local file to string (index.html)", 1, function() {
	forge.file.getLocal("index.html", function (file) {
		forge.file.string(file, function (data) {
			try {
				ok(data.indexOf('<html') >= 0, "Read index.html");
			} catch (e) {}
			start();
		});
	});
});

asyncTest("Cache file and get string content", 1, function() {
	forge.file.cacheURL("http://ops.trigger.io/75d92dce/tests/blank.html", function (file) {
		forge.file.string(file, function (data) {
			equal(data, "<html>Hello</html>\n", "Check file contents");
			start();
		});
	});
});

asyncTest("Get local file and check file info", 1, function() {
	forge.file.getLocal("img/glyphicons-halflings.png", function (file) {
		forge.file.info(file, function (info) {
			equal(info.size, 13826);
			start();
		}, function (e) {
			ok(false, "API call failure: " + e.message);
			start();
		});
	});
});

asyncTest("Cache file and check file info", 1, function() {
	forge.file.cacheURL("http://ops.trigger.io/75d92dce/tests/metadata_test.jpg", function (file) {
		forge.file.info(file, function (info) {
			equal(info.size, 33439);
			start();
		}, function (e) {
			ok(false, "API call failure: " + e.message);
			start();
		});
	});
});

asyncTest("Provide invalid file and check file info", 1, function() {
	var file = {
		"name": "movieCompressed17.mov",
		"uri": "/var/mobile/Containers/Data/Application/A031E5BB-FFF7-40E3-AC7C-6DFB14EB6625/Documents/movieCompressed17.mov",
		"type": "video"
	};
	forge.file.info(file, function (info) {
		ok(false, "API should not have succeeded: " + JSON.stringify(info));
		start();
	}, function (e) {
		ok(true, e.message);
		start();
	});
});
