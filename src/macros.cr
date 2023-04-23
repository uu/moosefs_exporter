macro define_gauges
  {% for stat in GAUGES %}
      @gauge[{{ stat }}] = Crometheus::Gauge.new({{ stat }}, "{{ stat.id }}")
  {% end %}
end
