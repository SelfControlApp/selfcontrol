#!/usr/bin/env ruby -w
#
#################################################################################
#                                                                               #
#     appcast_automation.rb                                                     #
#                                                                               #
#     author:   Craig Williams                                                  #
#     created:  2009-01-09                                                      #
#     half rewritten by Charlie Stigler from 2009-present :)                    #
#                                                                               #
#################################################################################
#                                                                               #
#     This program is free software: you can redistribute it and/or modify      #
#     it under the terms of the GNU General Public License as published by      #
#     the Free Software Foundation, either version 3 of the License, or         #
#     (at your option) any later version.                                       #
#                                                                               #
#     This program is distributed in the hope that it will be useful,           #
#     but WITHOUT ANY WARRANTY; without even the implied warranty of            #
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
#     GNU General Public License for more details.                              #
#                                                                               #
#     You should have received a copy of the GNU General Public License         #
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.     #
#                                                                               #
#################################################################################

class SelfControlRelease
    require 'fileutils'
    require 'yaml'
    require 'plist'
    require 'xcodeproj'

    YAML_FOLDER_PATH = "#{ENV['HOME']}/dev/selfcontrol/"
    SOURCE_FOLDER = __dir__.chomp
    
    def initialize
        @signature = ''
        @target_app = ARGV[0]
                        
        load_config
        parse_project_settings
                
        setup_variables
    end
    
    def execute!
        remove_old_build_create_new_build
        create_release_notes
        file_stats
        create_appcast_xml_snippet
    end
        
    # Exits if no config.yml file found.
    def load_config
        config_file_path = "#{YAML_FOLDER_PATH}/config.yml"
        unless File.exist?(config_file_path)
            log_message("No 'config.yml' file found in project directory.")
            exit
        end
        @config = YAML.load_file(config_file_path)
    end

    def parse_project_settings
        @version = `xcodebuild -project SelfControl.xcodeproj/ -showBuildSettings | grep "MARKETING_VERSION" | sed 's/[ ]*MARKETING_VERSION = //'`.chomp
        log_message("version is #{@version} and version.chomp is #{@version.chomp}")

        # Xcodeproj throws an insane number of warnings when opening the project
        # BUT still seems to work. so, just open it and suppress the warnings!
        project = nil
        suppress_warnings { project = Xcodeproj::Project.open("SelfControl.xcodeproj") }
        @min_system_version = project.build_settings("Release")['MACOSX_DEPLOYMENT_TARGET']
    end

    def setup_variables
        # General / archive variables
        @release_folder   = "#{SOURCE_FOLDER}/release".chomp
        @version_folder     = "#{@release_folder}/#{@version}".chomp
        @archive_filename = "SelfControl-#{@version}.zip" # underline character added
        @archive_path     = "#{@version_folder}/#{@archive_filename}".chomp

        # Appcast / release note variables
        @appcast_xml_name      = @config['appcast_xml_name'].chomp
        @appcast_xml_path      = "#{@version_folder}/#{@appcast_xml_name}"
        @download_base_url     = @config['download_base_url']
        @web_base_url          = @config['web_base_url']
        @releasenotes_url      = "#{@web_base_url}/releasenotes.html#collapse-#{@version.gsub('.', '-')}"
        @download_url          = "#{@download_base_url}#{@archive_filename}"
        @appcast_download_url  = "#{@web_base_url}#{@appcast_xml_name}"
    end
        
    def remove_old_build_create_new_build
        Dir.chdir(@release_folder)
        FileUtils.rm_rf("#{@version}")
        Dir.mkdir("#{@version}")
        `ditto -ck --keepParent --rsrc --sequesterRsrc "#{@target_app}" "#{@archive_path}"`
    end
        
    def file_stats
        @pubdate  = `date +"%a, %d %b %G %T %z"`
    end
    
    def get_dsa_signature
        puts "Generating DSA signature for archive at path #{@archive_path}"
        puts "Command: #{SOURCE_FOLDER}/Sparkle/bin/old_dsa_scripts/sign_update \"#{@archive_path}\" /Volumes/SelfControl\ Keys\ and\ Secrets/Sparkle\ Signing\ Keys/dsa_priv.pem"
        return `#{SOURCE_FOLDER}/Sparkle/bin/old_dsa_scripts/sign_update \"#{@archive_path}\" \"/Volumes/SelfControl\ Keys\ and\ Secrets/Sparkle\ Signing\ Keys/dsa_priv.pem\"`.chomp
    end
    
    def get_eddsa_signature_and_length_parameters
        puts "Generating edDSA signature parameters for archive at path #{@archive_path}"
        puts "Command: #{SOURCE_FOLDER}/Sparkle/bin/sign_update \"#{@archive_path}\""
        return `#{SOURCE_FOLDER}/Sparkle/bin/sign_update \"#{@archive_path}\"`.chomp
    end
    
    def create_appcast_xml_snippet
        appcast_xml =
        "    <item>
        <title>Version #{@version}</title>
        <sparkle:releaseNotesLink>
            #{@releasenotes_url}
        </sparkle:releaseNotesLink>
        <pubDate>#{@pubdate.chomp}</pubDate>
        <enclosure url=\"#{@download_url.chomp}\"
            sparkle:version=\"#{@version}\"
            sparkle:shortVersionString=\"#{@version}\"
            sparkle:dsaSignature=\"#{get_dsa_signature}\"
            #{get_eddsa_signature_and_length_parameters}
            type=\"application/octet-stream\"
        />
        <sparkle:minimumSystemVersion>#{@min_system_version}</sparkle:minimumSystemVersion>
    </item>"

        File.open(@appcast_xml_path, 'w') { |f| f.puts appcast_xml }
    end
    
    # Creates an html file with release notes
    def create_release_notes
        notes_file = "#{@version_folder}/releasenotes-#{@version}.html"
        File.open(notes_file, 'w') { |f| f.puts release_notes_html_snippet }
    end
    
    def log_message(msg)
        puts "\n\n----------------------------------------------"
        puts msg
        puts "----------------------------------------------\n\n"
    end
    
    # Method borrowed from Jakob Skjerning
    # Source: https://mentalized.net/journal/2010/04/02/suppress-warnings-from-ruby/
    def suppress_warnings
        original_verbosity = $VERBOSE
        $VERBOSE = nil
        result = yield
        $VERBOSE = original_verbosity
        return result
    end
        
    def release_notes_html_snippet
        @releasenotes_url      = "#{@web_base_url}/releasenotes.html#collapse-#{@version.gsub('.', '-')}"
        url_friendly_version = @version.gsub('.', '-')

        return "
        <div class=\"accordion-group\">
            <div class=\"accordion-heading\">
            <a href=\"#collapse-#{url_friendly_version}\" class=\"accordion-toggle\" data-toggle=\"collapse\" data-parent=\"#releasesAccordion\">
                    <h1 id=\"version-#{url_friendly_version}\">Version #{@version}</h1>
                </a>
            </div>
            <div id=\"collapse-#{url_friendly_version}\" class=\"accordion-body collapse\">
                <div class=\"accordion-inner\">
                    <h3>For Mac OS X #{@min_system_version}+ only. Please don't upgrade while a block is running.</h3>
                    <h3>Improvements</h3>
                    <ul>
                        <li>First great feature</li>
                        <li>Second great feature</li>
                    </ul>
                </div>
            </div>
        </div>"
    end
end
                                            
if __FILE__ == $0
    release = SelfControlRelease.new
    release.execute!
    release.log_message("Signed and packaged successfully!")
end
