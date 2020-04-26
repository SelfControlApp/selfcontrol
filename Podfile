source 'https://github.com/CocoaPods/Specs.git'
platform :osx, '10.8'

# cocoapods-prune-localizations doesn't appear to auto-detect pods properly, so using a manual list
supported_locales = ['Base', 'da', 'de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'nl', 'pt-BR', 'sv', 'tr', 'zh-Hans']
plugin 'cocoapods-prune-localizations', { :localizations => supported_locales }

target "SelfControl" do
    pod 'MASPreferences', '~> 1.1.4'
    pod 'FormatterKit/TimeIntervalFormatter', '~> 1.8.0'
    pod 'Sparkle', '~> 1.22'
    pod 'LetsMove', '~> 1.24'
end
