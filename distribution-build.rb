#!/usr/bin/env ruby -w
#
#################################################################################
#                                                                               #
#     appcast_automation.rb                                                     #
#                                                                               #
#     author:   Craig Williams                                                  #
#     created:  2009-01-09                                                      #
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
    require 'rubygems'
    require 'yaml'
    require 'tmpdir'
    require 'fileutils'
    require 'openssl'
    require 'nokogiri'
    require 'base64'
    
    MESSAGE_HEADER   = 'RUN SCRIPT DURING BUILD MESSAGE'
    YAML_FOLDER_PATH = "#{ENV['HOME']}/dev/selfcontrol/"
    
    def initialize
        @signature = ''
        require_release_build
        project_setup
        load_config
        
        # the build_now setting in the config.yml file
        # determines whether you want to perform this script
        # set to 'NO' until you are ready to publish
        exit_unless_build
        base_folder
        appcast_setup
    end
    
    def execute!
        create_appcast_folder_and_files
        remove_old_zip_create_new_zip
        file_stats
        create_appcast_xml
        puts "created appcast xml"
        copy_archive_to_appcast_path
        puts "copied archive to appcast path"
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
    
    def exit_unless_build
        unless @config['build_now'] == 'YES'
            log_message("The 'build_now' setting in 'config.yml' set to 'NO'\nIf you are wanting to include this script in\nthe build process change this setting to 'YES'")
            exit
        end
    end
    
    def project_setup
        @proj_dir         = ENV['BUILT_PRODUCTS_DIR']
        @proj_name        = ENV['PROJECT_NAME']
        @version          = "2.2.2"
        @build_number     = "2.2.2"
        @archive_filename = "#{@proj_name}-#{@version.chomp}.zip" # underline character added
        @archive_path     = "#{@proj_dir}/#{@archive_filename}"
    end
    
    def appcast_setup
        @appcast_xml_name      = @config['appcast_xml_name'].chomp
        @appcast_proj_folder   = "#{@config['appcast_basefolder']}/#{@proj_name}-#{@version}".chomp
        @appcast_xml_path      = "#{@appcast_proj_folder}/#{@appcast_xml_name}"
        @min_system_version    = @config['min_system_version']
        @download_base_url     = @config['download_base_url']
        @web_base_url          = @config['web_base_url']
        @css_file_name         = @config['css_file_name']
        @releasenotes_url      = "#{@web_base_url}/releasenotes.html#collapse-#{@version.chomp.gsub('.', '-')}"
        @download_url          = "#{@download_base_url}#{@archive_filename}"
        @appcast_download_url  = "#{@web_base_url}#{@appcast_xml_name}"
    end
    
    def base_folder
        @appcast_basefolder = @config['appcast_basefolder'].chomp
        File.expand_path(@appcast_basefolder) if @appcast_basefolder.start_with?("~")
    end
    
    def remove_old_zip_create_new_zip
        puts @proj_dir
        Dir.chdir(@proj_dir)
        `rm -f #{@proj_name}*.zip`
        `ditto -ck --keepParent --rsrc --sequesterRsrc "#{@proj_name}.app" "#{@archive_filename}"`
    end
    
    def copy_archive_to_appcast_path
        begin
            FileUtils.cp(@archive_path, @appcast_proj_folder)
            rescue
            log_message("There was an error coplogying the zip file to appcast folder\nError: #{$!}")
        end
    end
    
    def file_stats
        @size     = File.size(@archive_filename)
        @pubdate  = `date +"%a, %d %b %G %T %z"`
    end
    
    def get_signature
        puts "Generating signature for archive at path #{@archive_path}"
        puts "Command: /usr/local/bin/sparkle/sign_update \"#{@archive_path}\" /Volumes/SelfControl\ Keys\ and\ Secrets/Sparkle\ Signing\ Keys/dsa_priv.pem"
        return `/usr/local/bin/sparkle/sign_update \"#{@archive_path}\" \"/Volumes/SelfControl\ Keys\ and\ Secrets/Sparkle\ Signing\ Keys/dsa_priv.pem\"`.chomp
    end
    
    def create_appcast_xml
        appcast_xml =
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<rss version=\"2.0\" xmlns:sparkle=\"http://www.andymatuschak.org/xml-namespaces/sparkle\"  xmlns:dc=\"http://purl.org/dc/elements/1.1/\">
    <title>#{@proj_name}</title>
    <link>#{@appcast_download_url}</link>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
    <item>
        <title>Version #{@version.chomp}</title>
        <sparkle:releaseNotesLink>
            #{@releasenotes_url}
        </sparkle:releaseNotesLink>
        <pubDate>#{@pubdate.chomp}</pubDate>
        <enclosure url=\"#{@download_url.chomp}\"
            length=\"#{@size}\"
            sparkle:version=\"#{@version.chomp}\"
            sparkle:shortVersionString=\"#{@version.chomp}\"
            sparkle:dsaSignature=\"#{get_signature}\"
            type=\"application/octet-stream\"
        />
        <sparkle:minimumSystemVersion>#{@min_system_version}</sparkle:minimumSystemVersion>
    </item>
</rss>"

        File.open(@appcast_xml_path, 'w') { |f| f.puts appcast_xml }
    end
    
    # Creates the appcast folder if it does not exist
    # or is accidently moved or deleted
    # Creates an html file with generic note template if it does not exist
    # This way the notes file is named correctly as well
    # Creates a css file named from yml file with default css
    def create_appcast_folder_and_files
        base_folder = @appcast_basefolder
        project_folder = @appcast_proj_folder
        
        notes_file = "#{project_folder}/#{File.basename(@releasenotes_url.chomp)}"
        css_file_path = "#{project_folder}/#{@css_file_name}"
        
        Dir.mkdir(base_folder)    unless File.exist?(base_folder)
        Dir.mkdir(project_folder) unless File.exist?(project_folder)
        
        File.open(notes_file, 'w') { |f| f.puts release_notes_generic_text } unless File.exist?(notes_file)
        File.open(css_file_path, 'w') { |f| f.puts decompressed_css } unless File.exist?(css_file_path)
    end
    
    def log_message(msg)
        puts "\n\n----------------------------------------------"
        puts MESSAGE_HEADER
        puts msg
        puts "----------------------------------------------\n\n"
    end
    
    def decompressed_css
        return css_text.gsub(/\{\s+/, "{\n\t").gsub(/;/, ";\n\t").gsub(/^\s+\}/, "}").gsub(/^\s+/, "\t")
    end
    
    def release_notes_generic_text
        return "
        <html>
        <head>
        <meta http-equiv=\"content-type\" content=\"text/html;charset=utf-8\">
        <title>What's new in #{@proj_name}?</title>
        <meta name=\"robots\" content=\"anchors\">
        <link href=\"rnotes.css\" type=\"text/css\" rel=\"stylesheet\" media=\"all\">
        </head>
        
        <body>
        <br />
        <table class=\"dots\" width=\"100%\" border=\"0\" cellspacing=\"0\" cellpadding=\"0\" summary=\"Two column table with heading\">
        <tr>
        <td class=\"blue\" colspan=\"2\">
        <h3>#{@proj_name} #{@version.chomp} Release Notes</h3>
        </td>
        </tr>
        <tr>
        <td valign=\"top\">
        <p>
        <ul>
        <li>DESCRIPTION</li>
        </ul>
        </p>
        </td>
        </tr>
        </table>
        <br>
        </body>
        
        </html>"
    end
    
    # This css will be expanded to a normal, easily editable form when written to file
    def css_text
        return "
        body { margin: 2px 12px 12px; }
        h1 h2 h3 p ol ul a a:hover { font-family: \"Lucida Grande\", Arial, sans-serif; }
            h1 { font-size: 11pt; margin-bottom: 0; }
            h2 { font-size: 9pt; margin-top: 0; margin-bottom: -10px; }
            h3 { font-size: 9pt; font-weight: bold; margin-top: -4px; margin-bottom: -4px; }
            p { font-size: 9pt; line-height: 12pt; text-decoration: none; }
            ol { font-size: 9pt; line-height: 12pt; list-style-position: outside; margin-top: 12px; margin-bottom: 12px; margin-left: -18px; padding-left: 40px; }
            ol li { margin-top: 6px; margin-bottom: 6px; }
            ol p { margin-top: 6px; margin-bottom: 6px; }
            ul { font-size: 9pt; line-height: 12pt; list-style-type: square; list-style-position: outside; margin-top: 12px; margin-bottom: 12px; margin-left: -24px; padding-left: 40px; }
            ul li { margin-top: 6px; margin-bottom: 6px; }
            ul p { margin-top: 6px; margin-bottom: 6px; }
            a { color: #00f; font-size: 9pt; line-height: 12pt; text-decoration: none; }
                a:hover { color: #00f; text-decoration: underline; }
                    hr { text-decoration: none; border: solid 1px #bfbfbf; }
                        td { padding: 6px; }
                        #banner { background-color: #f2f2f2; background-repeat: no-repeat; padding: -2px 6px 0; position: fixed; top: 0; left: 0; width: 100%; height: 1.2em; float: left; border: solid 1px #bfbfbf; }
                        #caticon { margin-top: 3px; margin-bottom: -3px; margin-right: 5px; float: left; }
                        #pagetitle { margin-top: 12px; margin-bottom: 0px; margin-left: 40px; width: 88%; border: solid 1px #fff; }
                        #mainbox { margin-top: 2349px; padding-right: 6px; }
                        #taskbox { background-color: #e6edff; list-style-type: decimal; list-style-position: outside; margin: 12px 0; padding: 2px 12px; border: solid 1px #bfbfbf; }
                        #taskbox h2 { margin-top: 8; margin-bottom: -4px; }
                        #machelp { position: absolute; top: 2px; left: 10px ; }
                        #index { background-color: #f2f2f2; padding-right: 25px; top: 2px; right: 12px; width: auto; float: right; }
                        #next { position: absolute; top: 49px; left: 88%; }
                        #asindent { margin-left: 22px; font-size: 9pt; font-family: Verdana, Courier, sans-serif; }
                        .bread { color: #00f; font-size: 8pt; margin: -9px 0 -6px; }
                            .leftborder { color: #00f; font-size: 8pt; margin: -9px 0 -6px; padding-top: 2px; padding-bottom: 3px; padding-left: 8px; border-left: 1px solid #bfbfbf; }
                                .mult { margin-top: -8px; }
                                .blue { background-color: #e6edff; margin-top: -3px; margin-bottom: -3px; padding-top: -3px; padding-bottom: -3px; }
                                    .rightfloater { float: right; margin-left: 15px; }
                                    .rules { border-bottom: 1px dotted #ccc; }
                                        .dots { border: dotted 1px #ccc; }
                                            .seealso { margin-top: 4px; margin-bottom: 4px; }
                                            code { color: black; font-size: 9pt; font-family: Verdana, Courier, sans-serif; }"
    end
end
                                            
if __FILE__ == $0
    appcast = AppCast.new
    appcast.execute!
    appcast.log_message("It appears all went well with the build script!")
end
