
// Dynamic URL Blocker — background service worker (Manifest V3)

// ---- Helpers ----
function normalizeDomain(input) {
  // strip protocol, path, query, hash
  let domain = (input || "").trim().toLowerCase();
  domain = domain.replace(/^https?:\/\//, "");
  domain = domain.replace(/^www\./, "");
  domain = domain.split("/")[0].split("?")[0].split("#")[0];
  // allow punycode etc. Keep only allowed domain chars, dots, and dashes
  domain = domain.replace(/[^a-z0-9\.\-]/g, "");
  return domain;
}

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Build a regex that matches the domain and any subdomain, main-frame only.
function regexForDomain(domain) {
  const d = escapeRegex(domain);
  // ^https?://([sub.]* )?domain(/|:|$)
  return `^https?:\\/\\/([a-z0-9-]+\\.)*${d}(\\/|:|$)`;
}

// Simple deterministic hash for rule IDs (32-bit positive)
function hash32(str) {
  let h = 5381;
  for (let i = 0; i < str.length; i++) {
    h = ((h << 5) + h) ^ str.charCodeAt(i); // djb2 xor
    h = h | 0; // force 32-bit
  }
  // make positive and avoid 0 & small ids
  h = Math.abs(h);
  return (h % 2000000000) + 1000; // keep under Chrome's int32 max
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

async function fetchData() {
  // try {
  //   const response = await fetch("http://127.0.0.1:8080/");
  //   const data = await response.json();
  //   console.log("Swift app data:", data);
  // } catch (err) {
  //   console.error("Error fetching from Swift app:", err);
  // }
  try {
    const response = await fetch("http://127.0.0.1:8080/");
    const data = await response.json();
    console.log("Array from Swift:", data);

    // // iterate
    // data.forEach(item => {
    //   console.log(`${item.  } is ${item.status}`);
    // });
    // Parse into JS object
// const data = JSON.parse(jsonString);

// Access blocked domain list
const blockedDomains = data.blocked;

console.log(blockedDomains); 
// 👉 ["domain1.com", "domain2.com", "domain3.com"]

// Example: loop over them
blockedDomains.forEach(domain => {
  console.log("Blocked:", domain);
});
  return blockedDomains;
  } catch (err) {
    console.error("Fetch failed:", err);
    return [];
  }
}


async function getDynamicRuleIds() {
  const rules = await chrome.declarativeNetRequest.getDynamicRules();
  return rules.map(r => r.id);
}

async function applyRulesFrom(blockedDomains) {
  const desiredRules = blockedDomains.map(ruleForDomain);
  const desiredIds = new Set(desiredRules.map(r => r.id));
  const currentIds = new Set(await getDynamicRuleIds());

  // Remove any rules that shouldn't exist
  const removeRuleIds = [...currentIds].filter(id => !desiredIds.has(id));

  // Add rules that don't yet exist
  const addRules = desiredRules.filter(r => !currentIds.has(r.id));

  await chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds,
    addRules
  });
}

async function loadBlockedDomains() {
   const domains = await fetchData();
   return domains;
  // return new Promise(resolve => {
    // blockedDomains
    // chrome.storage.local.get({ blockedSites: [] }, (data) => {
    //   resolve(data.blockedSites || []);
    // });
  // });
}

async function saveBlockedDomains(domains) {
  return new Promise(resolve => {
    chrome.storage.local.set({ blockedSites: domains }, () => resolve());
  });
}

// ---- Lifecycle ----
chrome.runtime.onInstalled.addListener(async () => {
  const domains = await loadBlockedDomains();
  await applyRulesFrom(domains);
  console.log("Dynamic URL Blocker installed. Domains:", domains);
  // fetchData();
});

chrome.tabs.onCreated.addListener((tab) => {
  (async () => {
    console.log("New tab:", tab.id);
  const domains = await loadBlockedDomains();
  await applyRulesFrom(domains);
    // Example: get tab info with async API
    let tabInfo = await chrome.tabs.get(tab.id);
    console.log("Fetched tab info:", tabInfo);
  })();
});

chrome.windows.onCreated.addListener((window) => {
  (async () => {
  const domains = await loadBlockedDomains();
  await applyRulesFrom(domains);
    // Example: get tab info with async API
    let windowInfo = await chrome.tabs.get(window.id);
    console.log("New Window created:", windowInfo);
  })();
});

// ---- Messaging API for popup ----
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    if (message?.action === "list") {
      const domains = await loadBlockedDomains();
      sendResponse({ success: true, domains });
      return;
    }

    if (message?.action === "add") {
      let domain = normalizeDomain(message.site || "");
      if (!domain) {
        sendResponse({ success: false, error: "Please enter a valid domain (e.g., example.com)." });
        return;
      }
      let domains = await loadBlockedDomains();
      if (!domains.includes(domain)) {
        domains.push(domain);
        await saveBlockedDomains(domains);
        await applyRulesFrom(domains);
        sendResponse({ success: true, domains });
      } else {
        sendResponse({ success: false, error: "Already blocked." });
      }
      return;
    }

    if (message?.action === "remove") {
      const domain = normalizeDomain(message.site || "");
      let domains = await loadBlockedDomains();
      domains = domains.filter(d => d !== domain);
      await saveBlockedDomains(domains);
      await applyRulesFrom(domains);
      sendResponse({ success: true, domains });
      return;
    }

    sendResponse({ success: false, error: "Unknown action." });
  })();

  // Indicate we'll respond asynchronously
  return true;
});
