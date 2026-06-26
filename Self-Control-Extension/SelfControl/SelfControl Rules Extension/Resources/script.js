// Notify native extension that the content script is ready
safari.extension.dispatchMessage("ready");

(function () {
    // Listen for messages from the Swift extension
    safari.self.addEventListener("message", (event) => {
        if (event.name === "REDIRECT_BLOCKED_URL") {
            try {
                // Attempt to stop loading immediately
                if (document.readyState !== 'complete') {
                    window.stop();
                }
                // Redirect to a local "blocked" page
                const blockedPage = safari.extension.baseURI + "blocked.html";
                window.location.replace(blockedPage);
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

    // Notify on navigation events
    window.addEventListener("load", notifySwift);
    window.addEventListener("popstate", notifySwift);
    document.addEventListener("click", () => setTimeout(notifySwift, 10), true);
})();
