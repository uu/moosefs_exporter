require "http/server/handler"
require "crometheus/gauge"
require "./macros"
require "csv"

module MoosefsExporter
  class Agent
    include HTTP::Handler

    Log = ::Log.for("agent")
    # Cannot be generated dynamically cause of crystal symbol limitations.
    # You can't dynamically create symbols. When you compile your program, each symbol gets assigned a unique number.
    # https://crystal-lang.org/api/1.8.1/Symbol.html

    GAUGES = [
      :moosefs_master_info__ram_used,
      :moosefs_master_info__cpu_used_system,
      :moosefs_master_info__cpu_used_user,
      :moosefs_master_info__total_space,
      :moosefs_master_info__avail_space,
      :moosefs_master_info__free_space,
      :moosefs_master_info__trash_space,
      :moosefs_master_info__trash_files,
      :moosefs_master_info__sustained_space,
      :moosefs_master_info__sustained_files,
      :moosefs_master_info__all_fs_objects,
      :moosefs_master_info__directories,
      :moosefs_master_info__files,
      :moosefs_master_info__chunks,
      :moosefs_master_info__all_chunk_copies,
      :moosefs_master_info__regular_chunk_copies,
      :moosefs_master_info__last_successful_store,
      :moosefs_master_info__last_save_duration,
    ]

    Crometheus.alias NodeInfo = Crometheus::Gauge[:nodename]

    def initialize(@options : MoosefsExporter::Options)
      Log.level = :debug if @options.settings.debug?

      unless File.exists?("/usr/bin/mfscli")
        Log.error { "could not find /usr/bin/mfscli" }
        exit
      end
      Log.debug { "listening on #{@options.settings.host}:#{@options.settings.port}" }
      @gauge = Hash(Symbol, Crometheus::Gauge).new

      @gauge_nodeinfo = NodeInfo.new(:nodeinfo, "Name of this exporter")
      @gauge_nodeinfo[nodename: System.hostname].set(1)

      define_gauges
    end

    def call(context)
      stats = read_stats

      set_metrics(stats) unless stats.nil?

      read_master_chart("usedspace")

      call_next(context)
    end

    private def read_stats
      io, error = IO::Memory.new, IO::Memory.new
      proc = Process.new("mfscli", args: {"-n", "-s", "\|", "-SIG", "-H", @options.settings.masterhost.to_s, "-P",
                                          @options.settings.masterport.to_s}, output: io, error: error)

      case proc.wait
      when .success?
        data = io.to_s
        CSV.parse(data, separator: '|')
      else
        Log.error { "#{io} #{error}" }
        nil
      end
    end

    private def read_master_chart(chartname : String)
      io, error = IO::Memory.new, IO::Memory.new
      proc = Process.new("mfscli", args: {"-n", "-s", "\|", "-SMC", "-a", "1", "-d", "+#{chartname}", "-H",
                                         @options.settings.masterhost.to_s, "-P",
                                         @options.settings.masterport.to_s}, output: io, error: error)

      case proc.wait
      when .success?
        data = io.to_s
        CSV.parse(data, separator: '|')
      else
        Log.error { "#{io} #{error}" }
        nil
      end
    end

    private def gauges_with_data(stats)
      gauges_hash = Hash(String, String | Int32).new

      stats.map { |row| gauges_hash.merge!({"moosefs_#{prom_cleanup(row[0])}_#{prom_cleanup(row[1])}" => row[2]}) }
      gauges_hash
    end

    private def set_metrics(stats)
      data = gauges_with_data(stats)
      Log.debug { "DATA: #{data.inspect}" }
      GAUGES.each do |gauge|
        value = data[gauge.to_s]
        Log.debug { "#{gauge} ---> #{value}" }
        @gauge[gauge].set value.to_f || 0
      end
    end

    private def prom_cleanup(string)
      # cleans up colons, brackets, spaces and sets lower case
      string.gsub(/(:|\ )/, '_').gsub(/(\(|\))/, "").downcase
    end
  end
end
