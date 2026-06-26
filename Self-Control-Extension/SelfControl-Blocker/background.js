// Dynamic URL Blocker — Manifest V3 Service Worker

// ---------------- HELPERS ----------------

const API_URL = "http://127.0.0.1:8532/chrome";
const ALARM_NAME = "syncBlockedDomains";
const REFRESH_SECONDS = 10;


function normalizeDomain(input) {
  let domain = (input || "").trim().toLowerCase();
  domain = domain.replace(/^https?:\/\//, "");
  domain = domain.replace(/^www\./, "");
  domain = domain.split("/")[0];
  return domain.replace(/[^a-z0-9.\-]/g, "");
}

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function regexForDomain(domain) {
  return `^https?:\\/\\/([a-z0-9-]+\\.)*${escapeRegex(domain)}(\\/|:|$)`;
}

function hash32(str) {
  let h = 5381;
  for (let i = 0; i < str.length; i++) {
    h = ((h << 5) + h) ^ str.charCodeAt(i);
    h |= 0;
  }
  return (Math.abs(h) % 2000000000) + 1000;
}

function ruleForDomain(domain) {
  return {
    id: hash32(domain),
    priority: 1,
    action: { type: "block" },
    condition: {
      regexFilter: regexForDomain(domain),
      resourceTypes: ["main_frame"]
    }
  };
}

// ---------------- SERVER FETCH ----------------

async function fetchBlockedDomains() {
  try {
    const res = await fetch(API_URL);
    const data = await res.json();
    return data.blocked || [];
  } catch (err) {
    console.error("Fetch failed:", err);
    return [];
  }
}

// ---------------- RULE MANAGEMENT ----------------

async function getCurrentRuleIds() {
  const rules = await chrome.declarativeNetRequest.getDynamicRules();
  return new Set(rules.map(r => r.id));
}

async function applyRules(domains) {

  const desiredRules = domains.map(ruleForDomain);
  const desiredIds = new Set(desiredRules.map(r => r.id));
  const currentIds = await getCurrentRuleIds();

  const removeRuleIds = [...currentIds].filter(id => !desiredIds.has(id));
  const addRules = desiredRules.filter(r => !currentIds.has(r.id));

  if (removeRuleIds.length || addRules.length) {

    await chrome.declarativeNetRequest.updateDynamicRules({
      removeRuleIds,
      addRules
    });

    console.log("Rules updated", {
      added: addRules.length,
      removed: removeRuleIds.length
    });
  }
}

// ---------------- SYNC FUNCTION ----------------

async function syncBlockedDomains() {

  const domains = await fetchBlockedDomains();

  await chrome.storage.local.set({ blockedSites: domains });

  await applyRules(domains);

  console.log("Blocked domains synced:", domains);
}

// ---------------- EXTENSION LIFECYCLE ----------------

// install
chrome.runtime.onInstalled.addListener(async () => {

  await syncBlockedDomains();

  chrome.alarms.create(ALARM_NAME, {
    periodInMinutes: 1
  });

  console.log("Extension installed");
});
// fast refresh
setInterval(syncBlockedDomains, REFRESH_SECONDS * 1000);

// browser startup
chrome.runtime.onStartup.addListener(syncBlockedDomains);

// periodic refresh
chrome.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === ALARM_NAME) {
    syncBlockedDomains();
  }
});

// ---------------- POPUP MESSAGE API ----------------

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {

  (async () => {

    let domains = (await chrome.storage.local.get("blockedSites")).blockedSites || [];

    if (message.action === "list") {
      sendResponse({ success: true, domains });
      return;
    }

    if (message.action === "add") {

      const domain = normalizeDomain(message.site);

      if (!domain) {
        sendResponse({ success: false, error: "Invalid domain" });
        return;
      }

      if (!domains.includes(domain)) {
        domains.push(domain);
        await chrome.storage.local.set({ blockedSites: domains });
        await applyRules(domains);
      }

      sendResponse({ success: true, domains });
      return;
    }

    if (message.action === "remove") {

      const domain = normalizeDomain(message.site);

      domains = domains.filter(d => d !== domain);

      await chrome.storage.local.set({ blockedSites: domains });

      await applyRules(domains);

      sendResponse({ success: true, domains });
      return;
    }

    if (message.action === "refresh") {
      await syncBlockedDomains();
      sendResponse({ success: true });
      return;
    }

    sendResponse({ success: false });

  })();

  return true;
});