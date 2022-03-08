exports.normalizedWidthAndHeight_ = function (tpl) {
	return function (evt) {
		var e = evt.target;
		var dim = e.getBoundingClientRect();
		var x = evt.clientX - dim.left;
		var y = evt.clientY - dim.top;
		var nx = x / dim.width;
		var ny = y / dim.height;
		return tpl(nx)(ny);
	};
};
var getSVG = function (e) {
	return e.tagName === "svg" ? e : getSVG(e.parentNode);
};
exports.normalizedWidthAndHeightSvg_ = function (tpl) {
	return function (evt) {
		var e = getSVG(evt.target);
		var dim = e.getBoundingClientRect();
		var x = evt.clientX - dim.left;
		var y = evt.clientY - dim.top;
		var nx = x / dim.width;
		var ny = y / dim.height;
		return tpl(nx)(ny);
	};
};
exports.reverseS = function (s) {
	return s.split("").reverse().join("");
};
exports.hashCode = function (s) {
	var hash = 0,
		i,
		chr;
	if (s.length === 0) return hash;
	for (i = 0; i < s.length; i++) {
		chr = s.charCodeAt(i);
		hash = (hash << 5) - hash + chr;
		hash |= 0; // Convert to 32bit integer
	}
	return hash;
};
