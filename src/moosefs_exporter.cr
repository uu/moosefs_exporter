# prometheus exporter for moosefs
require "log"
require "./tools/*"
require "./agent"
require "crometheus"

module MoosefsExporter
  VERSION = "0.1.1"
  Log     = ::Log.for("main")

  class Daemon
    options = Options.new
    Log.info { "moosefs_exporter version #{VERSION} started" }
    Log.level = :debug if options.settings.debug?

    metrics_handler = Crometheus.default_registry.get_handler
    Crometheus.default_registry.path = "/metrics"

    # Serve metrics
    handlers = [HTTP::CompressHandler.new, HTTP::LogHandler.new, HTTP::ErrorHandler.new(true), MoosefsExporter::Agent.new(options), metrics_handler]
    server = HTTP::Server.new(handlers) do |context|
      if "/" == context.request.path
        context.response << MAIN_HTML
      else
        context.response.status_code = 404
        context.response << ERROR_HTML % context.request.path
      end
    end

    address = server.bind_tcp options.settings.host, options.settings.port

    Log.info { "Serving metrics at http://#{options.settings.host}:#{options.settings.port}/metrics" }
    Log.info { "Press Ctrl+C to exit" }
    server.listen

    MAIN_HTML = <<-HTML
        <html><body>
          <a href="/metrics">See metrics</a>
        </body></html>
HTML

    ERROR_HTML = <<-HTML
        <html><body>
          No resource at %s.
          <a href="/metrics">See metrics</a>
        </body></html>
HTML
  end
end
