(function () {
  "use strict";
  var params = new URLSearchParams(window.location.search);
  var code = params.get("ranking_download");
  if (!code || !/^n\d+[a-z]+$/i.test(code)) return;
  var novelUrl = "https://ncode.syosetu.com/" + code.toLowerCase() + "/";
  // The existing Download button owns the dialog and its submission logic.
  $(function () {
    $(document).one("shown.bs.modal", ".bootbox", function () {
      $(this).find("#download-input").val(novelUrl).trigger("input").focus();
    });
    var button = $("#control-panel .button-download").first();
    if (!button.length) button = $(".button-download").first();
    button.trigger("click");
    params.delete("ranking_download");
    var query = params.toString();
    history.replaceState(null, "", window.location.pathname + (query ? "?" + query : "") + window.location.hash);
  });
}());
