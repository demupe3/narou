(function () {
  "use strict";
  var form = document.getElementById("ranking-form"), kind = document.getElementById("ranking-kind");
  var date = document.getElementById("ranking-date"), status = document.getElementById("ranking-status");
  var container = document.getElementById("ranking-results"), completed = document.getElementById("ranking-completed");
  var hideRegistered = document.getElementById("ranking-hide-registered"), rows = [];
  var now = new Date();
  var jst = new Date(now.getTime() + 9 * 3600000 - 86400000);
  date.value = jst.toISOString().slice(0, 10);
  var storyDialog = document.getElementById("ranking-story-dialog");
  document.getElementById("ranking-story-close").addEventListener("click", function () { storyDialog.close(); });
  storyDialog.addEventListener("click", function (event) {
    if (event.target === storyDialog) storyDialog.close();
  });
  function node(tag, content) { var e = document.createElement(tag); e.textContent = content; return e; }
  function render() {
    container.textContent = "";
    var visible = rows.filter(function (r) { return (!completed.checked || r.end === 0) && (!hideRegistered.checked || !r.registered); });
    status.textContent = visible.length + "件を表示（取得 " + rows.length + "件）";
    visible.forEach(function (r) {
      var card = node("article", ""), heading = node("h3", "");
      card.style.cssText = "border-bottom:1px solid #888;padding:10px 0";
      var link = node("a", (r.rank || "-") + "位　" + (r.title || r.ncode));
      link.href = "https://ncode.syosetu.com/" + r.ncode + "/";
      link.target = "_blank"; link.rel = "noopener noreferrer";
      heading.appendChild(link); card.appendChild(heading);
      card.appendChild(node("p", (r.writer || "作者情報なし") + "　|　" + (r.points == null ? "-" : r.points) + " pt　|　" +
        (r.end === 0 ? "完結" : r.end === 1 ? "連載中" : "状態不明") + "　|　" +
        (r.episodes == null ? "話数不明" : r.episodes + "話") + "　|　" +
        (r.length == null ? "文字数不明" : Number(r.length).toLocaleString() + "文字") + (r.registered ? "　|　管理中" : "")));
      var storyButton = node("button", "あらすじを見る");
      storyButton.type = "button";
      storyButton.className = "ranking-story-button";
      storyButton.setAttribute("aria-haspopup", "dialog");
      storyButton.addEventListener("click", function () {
        document.getElementById("ranking-story-title").textContent = r.title || r.ncode;
        document.getElementById("ranking-story-text").textContent = r.story || "作品情報を取得できませんでした。";
        storyDialog.showModal();
      });
      card.appendChild(storyButton);
      if (r.registered) {
        var managed = node("span", "管理中");
        managed.className = "ranking-managed-label";
        card.appendChild(managed);
      } else {
        var download = node("a", "Downloadへ");
        download.className = "ranking-download-button";
        download.href = "/?ranking_download=" + encodeURIComponent(r.ncode);
        download.setAttribute("aria-label", (r.title || r.ncode) + "をDownloadに入力");
        card.appendChild(download);
      }
      container.appendChild(card);
    });
  }
  form.addEventListener("submit", function (e) {
    e.preventDefault(); rows = []; container.textContent = ""; status.textContent = "取得中…";
    fetch("/api/ranking?kind=" + encodeURIComponent(kind.value) + "&date=" + encodeURIComponent(date.value), {credentials: "same-origin"})
      .then(function (response) { return response.json().then(function (data) { if (!response.ok) throw new Error(data.error || "取得できませんでした"); return data; }); })
      .then(function (data) { rows = data.items; render(); })
      .catch(function (error) { status.textContent = "取得失敗: " + error.message; });
  });
  kind.addEventListener("change", function () {
    if (!date.value) return;
    var selected = new Date(date.value + "T00:00:00Z");
    if (kind.value === "w") selected.setUTCDate(selected.getUTCDate() - ((selected.getUTCDay() + 5) % 7));
    if (kind.value === "m" || kind.value === "q") selected.setUTCDate(1);
    date.value = selected.toISOString().slice(0, 10);
  });  completed.addEventListener("change", render); hideRegistered.addEventListener("change", render);
}());
