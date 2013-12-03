$(function () {
	forge.file.saveURL("http://192.168.2.144/~james/biggish.mp4", function (name) {
		forge.logging.info(JSON.stringify(name) + " done!");
// 		forge.file.saveURL("http://192.168.2.144/~james/biggish.mp4", function (name) {
// 			forge.logging.info(JSON.stringify(name) + " done!");
// 		});
	});
});
