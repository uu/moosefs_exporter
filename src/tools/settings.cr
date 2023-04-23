require "log"
require "option_parser"
require "validator"

module MoosefsExporter
  class Settings
    property host = "127.0.0.1"
    property port = 9192
    property masterhost = "mfsmaster"
    property masterport = 9421
    property? debug = false
  end

  class Options
    getter settings
    Log = ::Log.for("config")

    def initialize
      @settings = Settings.new

      OptionParser.parse do |p|
        p.banner = "moosefs_exporter [-d] [-h] [-v] [--host 127.0.0.1] [-p 9192] [-H 192.168.0.1] [-P 9421]"

        p.on("--host 127.0.0.1", "Address listen to") do |host|
          @settings.host = host
        end

        p.on("-p 9192", "Port listen to") do |port|
          @settings.port = port.to_i
        end

        p.on("-H", "--masterhost mfsmaster", "Address of the moosefs master") do |masterhost|
          @settings.masterhost = masterhost
        end

        p.on("-P", "--masterport 9421", "Port of the moosefs master") do |masterport|
          @settings.masterport = masterport.to_i
        end

        p.on("-d", "If set, debug messages will be shown.") do
          @settings.debug = true
        end

        p.on("-h", "--help", "Displays this message.") do
          puts p
          exit
        end

        p.on("-v", "--version", "Displays version.") do
          puts VERSION
          exit
        end
      end rescue abort "Invalid arguments, see --help."
    end
  end
end
