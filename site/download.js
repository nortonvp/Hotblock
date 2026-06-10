const notice = document.querySelector("#download-notice");
const closeNotice = document.querySelector("#close-download-notice");
let hideTimer;

function showDownloadNotice() {
  window.clearTimeout(hideTimer);
  notice.classList.add("visible");
  notice.setAttribute("aria-hidden", "false");
  hideTimer = window.setTimeout(hideDownloadNotice, 12000);
}

function hideDownloadNotice() {
  notice.classList.remove("visible");
  notice.setAttribute("aria-hidden", "true");
}

document.querySelectorAll(".direct-download").forEach((link) => {
  link.addEventListener("click", showDownloadNotice);
});

closeNotice.addEventListener("click", hideDownloadNotice);
