# frozen_string_literal: true

namespace :oas do
  desc "Print the OpenAPI spec"
  task :generate, [ :format, :output ] => [ :environment ] do |t, args|
    format = args[:format] || "yaml"
    output = args[:output] || "stdout"

    # it seems OasRails has special handling for JSON formatting that correctly
    # hides internal details that aren't handled correctly when going directly
    # to YAML, so get the correct JSON first that can then be used for whatever
    # the final output format is
    oas_json = JSON.pretty_generate(OasRails.build)

    case format
    when "json"
      oas = oas_json
    when "yaml"
      oas = JSON.parse(oas_json).to_yaml
    end

    case output
    when "stdout"
      print oas
    else
      File.open(output, "w") do |file|
        file.write(oas)
      end
    end
  end
end
