
const siteInput = document.getElementById("siteInput");
const addBtn = document.getElementById("addBtn");
const siteList = document.getElementById("siteList");

function normalizeDomain(input) {
  let domain = (input || "").trim().toLowerCase();
  domain = domain.replace(/^https?:\/\//, "");
  domain = domain.replace(/^www\./, "");
  domain = domain.split("/")[0].split("?")[0].split("#")[0];
  domain = domain.replace(/[^a-z0-9\.\-]/g, "");
  return domain;
}

function render(list) {
  siteList.innerHTML = "";
  if (!list || list.length === 0) {
    const li = document.createElement("li");
    li.innerHTML = '<span class="domain" style="color:#666;">No blocked domains yet.</span>';
    siteList.appendChild(li);
    return;
  }

  list.forEach(site => {
    const li = document.createElement("li");

    const span = document.createElement("span");
    span.className = "domain";
    span.textContent = site;

    // const removeBtn = document.createElement("button");
    // removeBtn.className = "remove";
    // removeBtn.textContent = "Unblock";
    // removeBtn.onclick = () => {
    //   chrome.runtime.sendMessage({ action: "remove", site }, (resp) => {
    //     render(resp.domains || []);
    //   });
    // };

    li.appendChild(span);
    // li.appendChild(removeBtn);
    siteList.appendChild(li);
  });
}

function load() {
  chrome.runtime.sendMessage({ action: "list" }, (resp) => {
    render(resp.domains || []);
  });
}

// addBtn.onclick = () => {
//   const raw = siteInput.value;
//   const site = normalizeDomain(raw);
//   if (!site) {
//     alert("Please enter a valid domain, e.g. example.com");
//     return;
//   }
//   chrome.runtime.sendMessage({ action: "add", site }, (resp) => {
//     if (!resp?.success) {
//       alert(resp?.error || "Failed to add.");
//       return;
//     }
//     siteInput.value = "";
//     render(resp.domains || []);
//   });
// };

// siteInput.addEventListener("keydown", (e) => {
//   if (e.key === "Enter") addBtn.click();
// });

document.addEventListener("DOMContentLoaded", load);
