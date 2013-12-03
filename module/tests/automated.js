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
}
