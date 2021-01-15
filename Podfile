source 'https://github.com/CocoaPods/Specs.git'
platform :osx, '10.10'

# cocoapods-prune-localizations doesn't appear to auto-detect pods properly, so using a manual list
supported_locales = ['Base', 'da', 'de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'nl', 'pt-BR', 'sv', 'tr', 'zh-Hans']
plugin 'cocoapods-prune-localizations', { :localizations => supported_locales }

target "SelfControl" do
    use_frameworks! :linkage => :static
    pod 'MASPreferences', '~> 1.1.4'
    pod 'FormatterKit/TimeIntervalFormatter', '~> 1.8.0'
    pod 'Sparkle', '~> 1.22'
    pod 'LetsMove', '~> 1.24'
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '6.1.2'
end

target "SelfControl Killer" do
    use_frameworks! :linkage => :static
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '6.1.2'
end

# we can't use_frameworks on these because they're command-line tools
# Sentry says we need use_frameworks, but they seem to work OK anyway?
target "SCKillerHelper" do
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '6.1.2'
end
target "selfcontrol-cli" do
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '6.1.2'
end
target "org.eyebeam.selfcontrold" do
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '6.1.2'
end
