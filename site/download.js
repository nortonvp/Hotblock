const notice = document.querySelector("#download-notice");
const closeNotice = document.querySelector("#close-download-notice");
const noticeTitle = document.querySelector("#download-notice-title");
const noticeCopy = document.querySelector("#download-notice-copy");
const releaseLink = document.querySelector("#release-link");
const copySiteLink = document.querySelector("#copy-site-link");
const isMobileDevice = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
let hideTimer;

function trackEvent(name, props) {
  if (typeof window.plausible === "function") {
    window.plausible(name, { props });
  }
}

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
  link.addEventListener("click", (event) => {
    const placement = link.dataset.downloadPlacement || "unknown";

    if (isMobileDevice) {
      event.preventDefault();
      noticeTitle.textContent = "Hotblock needs your Mac";
      noticeCopy.textContent = "Open hotblock.app on your Mac to download the app.";
      releaseLink.hidden = true;
      copySiteLink.hidden = false;
      trackEvent("Mobile Download Intent", { placement });
    } else {
      noticeTitle.textContent = "Download requested";
      noticeCopy.textContent = "If nothing happened, this browser blocks downloads. Open the release in Safari or Chrome.";
      releaseLink.hidden = false;
      copySiteLink.hidden = true;
      trackEvent("Download", { placement });
    }

    showDownloadNotice();
  });
});

document.querySelectorAll(".release-link").forEach((link) => {
  link.addEventListener("click", () => {
    trackEvent("Release View", {
      placement: link.dataset.releasePlacement || "unknown"
    });
  });
});

copySiteLink.addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText("https://hotblock.app");
    copySiteLink.textContent = "Copied";
    trackEvent("Copy Mac URL", { placement: "mobile-download-notice" });
  } catch {
    noticeCopy.textContent = "Open hotblock.app on your Mac to download the app.";
  }
});

closeNotice.addEventListener("click", hideDownloadNotice);
