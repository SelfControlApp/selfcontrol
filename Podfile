source 'https://github.com/CocoaPods/Specs.git'

target "SelfControl" do
	pod 'MASPreferences', '~> 1.1.4'
	pod 'FormatterKit/TimeIntervalFormatter', '~> 1.7'
	pod 'Sparkle', '~> 1.14'
end

pre_install do |installer|
	supported_locales = ['base', 'en', 'de', 'es', 'it', 'ja', 'ko', 'pt', 'pt-br', 'pt_br', 'sv', 'tr', 'zh-hans', 'zh_hans', 'zh-cn', 'zh_cn']

	Dir.glob(File.join(installer.sandbox.pod_dir('FormatterKit'), '**', '*.lproj')).each do |bundle|
		if (!supported_locales.include?(File.basename(bundle, ".lproj").downcase))
			puts "Removing #{bundle} from FormatterKit"
			FileUtils.rm_rf(bundle)
		end
	end

	Dir.glob(File.join(installer.sandbox.pod_dir('Sparkle'), '**', '*.lproj')).each do |bundle|
		if (!supported_locales.include?(File.basename(bundle, ".lproj").downcase))
			puts "Removing #{bundle} from Sparkle"
			FileUtils.rm_rf(bundle)
		end
	end
end
