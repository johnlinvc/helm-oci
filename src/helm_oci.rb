HELM_BIN = "helm"

class HelmOci
  class CLI
    def helm_exec(cmd, *args)
      full_cmd = "HELM_EXPERIMENTAL_OCI=1 #{HELM_BIN} #{cmd} #{args.join(" ")}"
      $stderr.puts `#{full_cmd}`
    end

    def auth_param
      "#{@user}:#{@pw}"
    end

    def log(*obj)
      $stderr.puts(*obj)
    end

    def query_oci(*paths)
      uri = ["https://#{auth_param}@#{@registry}",*paths].join("/")
      $stderr.puts(uri)
      curl = Curl.new
      response = curl.get(uri)
      json_body = JSON.parse(response.body)
      log(json_body)
      json_body
    end

    def get_chart_versions(chart)
      tag_list = query_oci("v2/#{chart}/tags/list")
      tag_list["tags"].map do |tag|
        {
          "apiVersion" => "v2",
          "version" => tag,
          "name" => chart,
          "urls" => ["oci+login://#{auth_param}@#{@repo}/menifests/#{tag}"]
        }
      end
    end

    def gen_index(chart)
      $stderr.puts("gen index for #{chart}")
      versions = get_chart_versions(chart)
      yaml = {"apiVersion" => "v1", "entries" => {chart => versions}}
      yaml_s = YAML.dump(yaml)
      $stderr.puts(yaml_s)
      puts yaml_s
    end

    def parse_arg(argv)
      $stderr.puts(argv)
      @uri = argv[4]
      @uri =~ /^oci\+login:\/\/([^:]+):([^@]+)@(.*)\/([^\/]+)$/
      if !$~
          $stderr.puts("repo format error")
      end
      @user, @pw, @repo, @action = $~.captures
      @repo =~ /^([^\/]+)\/(.+)$/
      if !$~
          $stderr.puts("registry format error")
      end
      @registry, @chart = $~.captures
    end

    def run(argv)
      parse_arg(argv)
      case @action
      when "index.yaml"
        gen_index(@chart)
      end
    end
  end
end

cli = HelmOci::CLI.new
cli.run(ARGV)
