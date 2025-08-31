# SelfControl Development Setup Guide

This document outlines the exact setup needed for developing the SelfControl app that uses NetworkExtension for filtering network traffic.

## Prerequisites

- Xcode 16.0 or later
- macOS (15.0) or later
- Apple Developer account with Network Extension entitlements
- Administrator privileges on your Mac

## Development Setup Steps

### 1. Disable System Integrity Protection (SIP)

For NetworkExtension development, SIP needs to be disabled to allow proper installation and uninstallation of system extensions during development:

1. Boot into Recovery Mode (restart holding Cmd+R)
2. Open Terminal from Utilities menu
3. Run: `csrutil disable`
4. Restart your Mac

> ⚠️ **IMPORTANT**: Disabling SIP reduces your system's security. Only do this on a development machine, not on your primary production machine.

### 2. Configure Post-Build Actions

To ensure fresh installs of the system extension during development, add two critical post-build actions to your Xcode project:

1. Open your project in Xcode
2. Select your main app target
3. Go to "Build Phases"
4. Add a new "Run Script" phase (click the + button)
5. Add the following script:

```bash
# Uninstall the previous system extension first
systemextensionsctl uninstall A4L93BSQEG com.application.SelfControl.SelfControlExtension

# Copy the app to /Applications
ditto "${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}" "/Applications/${FULL_PRODUCT_NAME}"
```

> Note: Replace `A4L93BSQEG` with your actual Team ID and `com.application.SelfControl.SelfControlExtension` with your actual extension bundle ID if different.

### 3. Bundle Identifier Setup

Ensure your bundle identifiers are set up correctly:

- Main App: `com.application.SelfControl`
- Extension: `com.application.SelfControl.SelfControlExtension`

### 4. Configure Info.plist for Network Extension

In your Network Extension's Info.plist, ensure proper configuration:

```xml
<key>NetworkExtension</key>
<dict>
    <key>NEMachServiceName</key>
    <string>$(TeamIdentifierPrefix)com.application.SelfControl.SelfControlExtension</string>
    <key>NEProviderClasses</key>
    <dict>
        <key>com.apple.networkextension.filter-data</key>
        <string>$(PRODUCT_MODULE_NAME).FilterDataProvider</string>
    </dict>
</dict>
```

### 5. Development Workflow

With this setup, your development workflow becomes:

1. Make code changes in Xcode
2. Build the project (⌘B)
   - This will automatically uninstall the previous extension
   - Then copy the new build to /Applications
3. Launch the app from /Applications (not from Xcode)
4. Check Console.app for logs with the prefix `[EADBUG]`

### 6. Troubleshooting

If you encounter issues:

- Verify the app is properly copied to `/Applications`
- Check that the system extension uninstall command is working correctly
- Inspect Console.app for any error messages
- Verify your Team ID is correct in the post-build script
- Ensure bundle identifiers match between the app, extension, and post-build script

### 7. Re-enabling SIP After Development

When you're done with development and ready to deploy:

1. Boot into Recovery Mode
2. Run: `csrutil enable`
3. Restart your Mac

## Known Limitations

- Each build requires a fresh installation due to NetworkExtension constraints
- The app must run from /Applications to function properly
- With SIP disabled, your development machine has reduced security protections
- NetworkExtension development generally requires more manual steps than typical app development

## Conclusion

This setup automates the most tedious parts of NetworkExtension development by:
1. Ensuring old extensions are uninstalled before new ones are installed
2. Automatically placing the app in the required location (/Applications)
3. Allowing for rapid iteration despite NetworkExtension's constraints

By following these specific steps, you should be able to develop your NetworkExtension-based app more efficiently.