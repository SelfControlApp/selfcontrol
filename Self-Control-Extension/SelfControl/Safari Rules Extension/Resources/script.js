//safari.extension.dispatchMessage("load")
//document.addEventListener("DOMContentLoaded", function(event) {
//    console.log("DOMContentLoaded");
//    safari.extension.dispatchMessage("[SC] 🔍] Hello World!");
//});

//
//window.addEventListener("load", function () {
//    console.log("Page fully loaded");
//    safari.extension.dispatchMessage("[SC] 🔍] Hello World! Load");
//});
//document.addEventListener("click", function (event) {
//    safari.extension.dispatchMessage("PAGE_CLICKED", {
//        url: window.location.href,
//        x: event.clientX,
//        y: event.clientY
//    });
//});
//function notifySwift(data) {
//    safari.extension.dispatchMessage("REQUEST_DETECTED", data);
//}
//
//// Example usage:
//notifySwift({ url: location.href, time: Date.now() });
//safari.self.addEventListener("message", function(event) {
//    if (event.name === "SWIFT_ACK") {
//        console.log("[SC] 🔍] Swift acknowledged:", event.message);
//    }
//});
//(function() {
//
//    function checkURL() {
//            console.log("[SC] 🔍] Swift acknowledged:", location.href);
//
//        if (location.href.match(/facebook\.com\/friends/)) {
//            // Stop page loading immediately
//            window.stop();
//
//            // Notify Swift
//            safari.extension.dispatchMessage("BLOCK_FRIENDS_PAGE", {
//                url: location.href
//            });
//        }
//    }
//
//    // Run on load + on history navigation
//    checkURL();
//    document.addEventListener("DOMContentLoaded", checkURL);
//
//    // For SPA router (Facebook uses React navigation)
//    const pushState = history.pushState;
//    history.pushState = function() {
//        pushState.apply(history, arguments);
//        checkURL();
//    };
//
//})();
// Injected script for Safari App Extension
// Blocks navigation to facebook.com/friends by stopping load and notifying the extension.
//(function() {
//
//    function isFriendsPath(href) {
//        try {
//            // Normalize and check path+hash+query
//            const url = new URL(href, location.origin);
//            // Check hostname contains facebook.com and path begins with /friends
//            return /(^|\.)facebook\.com$/.test(url.hostname) && url.pathname.startsWith('/friends');
//        } catch (e) {
//            return false;
//        }
//    }
//
//    function notifySwift() {
//                console.log("[SC] 🔍] notifySwift:");
//
//        try {
//            // Stop network activity for this page
//            if (typeof window.stop === 'function') {
//                window.stop();
//            }
//
//            // Dispatch message to Safari App Extension
//            if (window.safari && safari.extension && safari.extension.dispatchMessage) {
//                console.log("[SC] 🔍] notifySwift:if (window.safari");
//
//                safari.extension.dispatchMessage("BLOCK_FRIENDS_PAGE", {
//                    url: location.href,
//                    time: Date.now()
//                });
//            } else {
//                console.warn("[SC] 🔍] Safari extension messaging API unavailable");
//            }
//        } catch (err) {
//            console.error("[SC] 🔍] notifySwift error:", err);
//        }
//    }
//
//    function checkURL() {
//        if (isFriendsPath(location.href)) {
//            notifySwift();
//        }
//    }
//
//    // initial check
//    checkURL();
//
//    // handle regular page load
//    document.addEventListener("DOMContentLoaded", checkURL);
//
//    // handle SPA navigation (monkey-patch history)
//    (function(history) {
//        const pushState = history.pushState;
//        history.pushState = function() {
//            const result = pushState.apply(this, arguments);
//            setTimeout(checkURL, 10);
//            return result;
//        };
//        const replaceState = history.replaceState;
//        history.replaceState = function() {
//            const result = replaceState.apply(this, arguments);
//            setTimeout(checkURL, 10);
//            return result;
//        };
//    })(window.history);
//
//    // handle popstate (back/forward)
//    window.addEventListener('popstate', function() {
//        setTimeout(checkURL, 10);
//    });
//
//    // observe clicks on anchors that may bypass history
//    document.addEventListener('click', function(e) {
//        setTimeout(checkURL, 10);
//    }, true);
//
//    // for good measure, observe mutations — some SPAs do their own routing
//    const observer = new MutationObserver(function() {
//        checkURL();
//    });
//    observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
//
//})();

//(function () {
//
//    function notifySwift() {
//        try {
//            if (typeof window.stop === "function") {
//                window.stop();
//            }
//
//            if (
//                window.safari &&
//                safari.extension &&
//                typeof safari.extension.dispatchMessage === "function"
//            ) {
//                safari.extension.dispatchMessage("PAGE_VISIT", {
//                    url: location.href,
//                    time: Date.now(),
//                });
//            }
//        } catch (err) {
//            console.error("[SC] notifySwift error:", err);
//        }
//    }
//
//    function onURLChange() {
//        console.log("[SC] 🔍 onURLChange:", location.href);
//        notifySwift();
//    }
//
//    // Initial load
//    onURLChange();
//
//    // Observe SPA navigation (pushState, replaceState)
//    (function (history) {
//        ["pushState", "replaceState"].forEach(function (method) {
//            const original = history[method];
//            history[method] = function () {
//                const result = original.apply(this, arguments);
//                setTimeout(onURLChange, 10);
//                return result;
//            };
//        });
//    })(window.history);
//
//    window.addEventListener("popstate", () => setTimeout(onURLChange, 10));
//    document.addEventListener("click", () => setTimeout(onURLChange, 10), true);
//
//    // ✅ Wait for DOM before attaching MutationObserver
//    function setupObserver() {
//        const target = document.body;
//        if (!target) {
//            // If body not yet available, retry shortly
//            console.warn("[SC] document.body not ready, retrying...");
//            return setTimeout(setupObserver, 50);
//        }
//
//        try {
//            const observer = new MutationObserver(() => onURLChange());
//            observer.observe(target, { childList: true, subtree: true });
//            console.log("[SC] ✅ MutationObserver attached");
//        } catch (err) {
//            console.error("[SC] MutationObserver error:", err);
//        }
//    }
//
//    if (document.readyState === "loading") {
//        document.addEventListener("DOMContentLoaded", setupObserver);
//    } else {
//        setupObserver();
//    }
//
//})();

//if (safari.self && safari.self.addEventListener) {
//    safari.self.addEventListener("message", function(event) {
//        if (event.name === "REDIRECT_BLOCKED_URL" && event.message && event.message.redirect) {
//            console.log("[SC] 🔍] REDIRECT_BLOCKED_URL:");
//
//            location.replace(event.message.redirect);
//        }
//    });
//}

(function () {

    // Listen for messages from the Swift extension
    safari.self.addEventListener("message", (event) => {
        if (event.name === "REDIRECT_BLOCKED_URL") {
            const redirectURL = event.message.redirect;
            console.log("[SC] 🚫 Redirecting to:", redirectURL);

            try {
                window.stop(); // stop current load
//                location.href = redirectURL; // redirect
                const blockedPage = safari.extension.baseURI + "blocked.html";
                window.location.href = blockedPage;
            } catch (err) {
                console.error("[SC] redirect error:", err);
            }
        }
    });

    // Send PAGE_VISIT message
    function notifySwift() {
        try {
            if (window.safari && safari.extension && safari.extension.dispatchMessage) {
                safari.extension.dispatchMessage("PAGE_VISIT", {
                    url: location.href,
                    time: Date.now(),
                });
            }
        } catch (err) {
            console.error("[SC] notifySwift error:", err);
        }
    }

    // Observe navigation changes (simplified)
    window.addEventListener("load", notifySwift);
    window.addEventListener("popstate", notifySwift);
    document.addEventListener("click", () => setTimeout(notifySwift, 10), true);

})();
