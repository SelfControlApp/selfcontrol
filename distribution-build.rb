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

class AppCast
    require 'yaml'
    require 'plist'
    
    MESSAGE_HEADER   = 'RUN SCRIPT DURING BUILD MESSAGE'
    YAML_FOLDER_PATH = "#{ENV['HOME']}/dev/selfcontrol/"
    SRCROOT = ENV['SRCROOT'].chomp
    
    def initialize
        @signature = ''
        require_release_build
        parse_project_settings
        project_setup
        load_config
        
        appcast_setup
    end
    
    def execute!
        create_appcast_folder_and_files
        remove_old_zip_create_new_zip
        file_stats
        create_appcast_xml_snippet
    end
    
    # Only works for Release builds
    # Exits upon failure
    def require_release_build
        if ENV["BUILD_STYLE"] == 'Debug'
            log_message("Distribution target requires 'Release' build style")
            exit
        end
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
        plist = Plist.parse_xml("#{SRCROOT}/Info.plist")
        
        @version = plist['CFBundleShortVersionString']
    end

    def project_setup
        @proj_dir         = ENV['BUILT_PRODUCTS_DIR']
        @proj_name        = ENV['PROJECT_NAME']
        @archive_filename = "#{@proj_name}-#{@version.chomp}.zip" # underline character added
        @archive_path     = "#{SRCROOT}/release/#{@archive_filename}".chomp
    end

    def appcast_setup
        @appcast_xml_name      = @config['appcast_xml_name'].chomp
        @appcast_release_folder   = "#{SRCROOT}/release".chomp
        @appcast_xml_path      = "#{@appcast_release_folder}/#{@appcast_xml_name}"
        @min_system_version    = ENV['MACOSX_DEPLOYMENT_TARGET']
        @download_base_url     = @config['download_base_url']
        @web_base_url          = @config['web_base_url']
        @releasenotes_url      = "#{@web_base_url}/releasenotes.html#collapse-#{@version.chomp.gsub('.', '-')}"
        @download_url          = "#{@download_base_url}#{@archive_filename}"
        @appcast_download_url  = "#{@web_base_url}#{@appcast_xml_name}"
    end
        
    def remove_old_zip_create_new_zip
        puts @proj_dir
        Dir.chdir(@proj_dir)
        `rm -f #{@proj_name}*.zip`
        `ditto -ck --keepParent --rsrc --sequesterRsrc "#{@proj_name}.app" "#{@archive_path}"`
    end
        
    def file_stats
        @pubdate  = `date +"%a, %d %b %G %T %z"`
    end
    
    def get_dsa_signature
        puts "Generating DSA signature for archive at path #{@archive_path}"
        puts "Command: #{SRCROOT}/Pods/Sparkle/bin/old_dsa_scripts/sign_update \"#{@archive_path}\" /Volumes/SelfControl\ Keys\ and\ Secrets/Sparkle\ Signing\ Keys/dsa_priv.pem"
        return `#{SRCROOT}/Pods/Sparkle/bin/old_dsa_scripts/sign_update \"#{@archive_path}\" \"/Volumes/SelfControl\ Keys\ and\ Secrets/Sparkle\ Signing\ Keys/dsa_priv.pem\"`.chomp
    end
    
    def get_eddsa_signature_and_length_parameters
        puts "Generating edDSA signature parameters for archive at path #{@archive_path}"
        puts "Command: #{SRCROOT}/Pods/Sparkle/bin/sign_update \"#{@archive_path}\""
        return `#{SRCROOT}/Pods/Sparkle/bin/sign_update \"#{@archive_path}\"`.chomp
    end
    
    def create_appcast_xml_snippet
        appcast_xml =
        "    <item>
        <title>Version #{@version.chomp}</title>
        <sparkle:releaseNotesLink>
            #{@releasenotes_url}
        </sparkle:releaseNotesLink>
        <pubDate>#{@pubdate.chomp}</pubDate>
        <enclosure url=\"#{@download_url.chomp}\"
            sparkle:version=\"#{@version.chomp}\"
            sparkle:shortVersionString=\"#{@version.chomp}\"
            sparkle:dsaSignature=\"#{get_dsa_signature}\"
            #{get_eddsa_signature_and_length_parameters}
            type=\"application/octet-stream\"
        />
        <sparkle:minimumSystemVersion>#{@min_system_version}</sparkle:minimumSystemVersion>
    </item>"

        File.open(@appcast_xml_path, 'w') { |f| f.puts appcast_xml }
    end
    
    # Creates the appcast folder if it does not exist
    # or is accidently moved or deleted
    # Creates an html file with generic note template if it does not exist
    # This way the notes file is named correctly as well
    def create_appcast_folder_and_files
        project_folder = @appcast_release_folder
        
        notes_file = "#{project_folder}/releasenotes-#{@version}.html"
        
        Dir.mkdir(project_folder) unless File.exist?(project_folder)
                
        File.open(notes_file, 'w') { |f| f.puts release_notes_html_snippet } unless File.exist?(notes_file)
    end
    
    def log_message(msg)
        puts "\n\n----------------------------------------------"
        puts MESSAGE_HEADER
        puts msg
        puts "----------------------------------------------\n\n"
    end
        
    def release_notes_html_snippet
        @releasenotes_url      = "#{@web_base_url}/releasenotes.html#collapse-#{@version.chomp.gsub('.', '-')}"
        url_friendly_version = @version.chomp.gsub('.', '-')

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
    appcast = AppCast.new
    appcast.execute!
    appcast.log_message("It appears all went well with the build script!")
end
