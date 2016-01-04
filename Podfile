source 'https://github.com/CocoaPods/Specs.git'

pod 'MASPreferences', '~> 1.1.2'
pod 'FormatterKit/TimeIntervalFormatter', '~> 1.7'
pod 'Sparkle'

pre_install do |installer|
	supported_locales = ['base', 'en', 'de', 'es', 'it', 'ja', 'ko', 'pt-br', 'pt_br', 'sv', 'tr', 'zh-hans', 'zh_hans']

	Dir.glob(File.join(installer.sandbox.pod_dir('FormatterKit'), '**', '*.lproj')).each do |bundle|
		if (!supported_locales.include?(File.basename(bundle, ".lproj").downcase))
			puts "Removing #{bundle}"
			FileUtils.rm_rf(bundle)
		end
	end
end