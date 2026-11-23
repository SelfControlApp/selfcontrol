# SelfControl Next

A SwiftUI rewrite of SelfControl focused on **apps**:

- **App Limits**: a daily time allowance for each app, the same every day or custom per weekday. Usage counts only while the app is in front and you're active.
- **Downtime**: a schedule like macOS Screen Time's Downtime (every day or per day, overnight windows supported). During Downtime only *Always Allowed* apps can be used.
- **Focus Session**: the classic SelfControl block. Pick websites and apps and a duration, start, and it can't be stopped early, even by quitting, restarting, or deleting the app.
- **Website blocking**, done the same way as the original SelfControl (`/etc/hosts` plus a `pf` firewall anchor), in Focus Sessions and optionally during Downtime.
- **Website Limits**: SelfControl tracks time on each site (the active tab of Safari, Chrome, Edge, Brave, Arc, Vivaldi or Opera when that browser is in front). Any site over its daily limit (1 hour by default) is blocked in every browser until midnight. Firefox and Zen can't be tracked, because they don't let other apps read their tabs.
- **Website Whitelist**: sites, including their subdomains, that are never counted or limited.
- **Gallery**: Focus Lists such as "Study", each with apps and websites to block and to allow. Start one as a Focus Session. Each list either exempts its allowed items from limits, or blocks everything except them; the second works like the original SelfControl's allowlist mode and applies to the whole network.
- **"Is this a good time?"**: before a limit or Downtime blocks an app or website, SelfControl asks whether to block now or delay. You type how many minutes to delay, up to 30, and when the delay runs out it asks again, as many times as you like. "Block Now", or not answering within 60 seconds, makes the block stick for the rest of the day (for a limit) or the rest of Downtime. Focus Sessions, Strict Mode, and Downtime with "Block at Downtime" turned on never ask.
- **Overview**, with today's screen time, most-used apps, a 7-day chart and limit progress, plus a menu bar item.
- **Strict Mode** locks limits and Downtime so they can only be made stricter, and removes every "Ignore" option. Turning it off only takes effect after a cooldown you choose (1 hour to 3 days).

## Build

Needs only the Xcode Command Line Tools (macOS 14+):

    ./build.sh
    open build/SelfControl.app

Data lives in `~/Library/Application Support/SelfControlNext/`.

## The helper

Website blocking, Focus Sessions that survive restarts, and Strict Mode rely on a root LaunchDaemon. It's the same binary run as `SelfControlNext --daemon`, installed from Settings → Protection with an admin password:

- `/Library/PrivilegedHelperTools/org.eyebeam.SelfControlNext.helper`, which is registered via `/Library/LaunchDaemons/org.eyebeam.SelfControlNext.helper.plist` and talks to the app over XPC.
- It stores the authoritative state (the focus session, locked rules, today's usage) in `/Library/Application Support/SelfControlNext/helper-state.json`, which is owned by root.
- Every request can only make things stricter. The exceptions are turning off Strict Mode after its cooldown, and uninstalling, which the helper refuses while a session or Strict Mode is active.
- Every 10 seconds it checks that its `/etc/hosts` entries and `pf` rules are still in place, and re-applies them if they were edited out.
- If the app stops checking in during a session or Strict Mode, the helper relaunches it. In the meantime it terminates blocked apps itself, and counts any time a limited app is open toward that app's limit.
- Logs go to `/Library/Logs/SelfControlNext-helper.log`.

## Limitations

Like the original SelfControl, this guards against impulse, not against an administrator who is determined to get around it. Someone with `sudo` can unload the helper and edit `/etc/hosts`. Browsers that use DNS-over-HTTPS bypass `/etc/hosts`, but the `pf` rules still block the sites' IP addresses as they resolved when the block started. Only blocklists are supported; the original's allowlist mode isn't.
