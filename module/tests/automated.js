/* global forge, module, asyncTest, equal, start, ok */
module("forge.file");

if (forge.is.mobile()) {
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
}
