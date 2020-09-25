HELM_BIN = "helm"

class HelmOci
  class CLI
    def helm_exec(cmd, *args)
      full_cmd = "HELM_EXPERIMENTAL_OCI=1 #{HELM_BIN} #{cmd} #{args.join(" ")}"
      log `#{full_cmd}`
    end

    def user
      ENV['OCI_USER']
    end

    def pw
      ENV['OCI_PW']
    end

    def auth_param
      "#{user}:#{pw}"
    end

    def log(*obj)
      $stderr.puts(*obj) if ENV["HELM_OCI_DEBUG"] == "1"
    end

    def query_oci(*paths)
      uri = ["https://#{auth_param}@#{@registry}",*paths].join("/")
      curl = Curl.new
      response = curl.get(uri)
      json_body = JSON.parse(response.body)
      log(json_body)
      json_body
    end

    def get_chart_versions(chart)
      tag_list = query_oci("v2/#{chart}/tags/list")
      tag_list["tags"].find_all do |tag|
        tag =~ /^\d+\.\d+\.\d+-?.*/
      end.map do |tag|
        {
          "apiVersion" => "v2",
          "version" => tag,
          "name" => chart,
          "urls" => ["oci+login://#{@repo}/#{chart}/#{chart}-#{tag}.tgz?tag=#{tag}"]
        }
      end
    end

    def get_chart_names
      chart_list = query_oci("v2/_catalog")
      log chart_list
      chart_list["repositories"]
    end

    def gen_index
      charts = get_chart_names
      entries = charts.map do |chart|
        [chart , get_chart_versions(chart)]
      end.to_h
      yaml = {"apiVersion" => "v1", "entries" => entries}
      yaml_s = YAML.dump(yaml)
      log(yaml_s)
      puts yaml_s
    end

    def parse_arg(argv)
      log(argv)
      @uri = argv[4]
      @uri =~ /^oci\+login:\/\/(.*)\/([^\/]+)$/
      if !$~
          log("repo format error")
      end
      @repo, @action = $~.captures
      @repo =~ /^([^\/]+)(\/(.+))?$/
      if !$~
          log("registry format error")
      end
      @registry, dontcare, @chart = $~.captures
    end

    def fetch_package(version)
      dir = Dir.mktmpdir
      trap(:EXIT) {
        # TODO(johnlinvc): remove the tmpdir
      }
      log(@chart, version)
      log(dir)
      helm_exec("registry login -u #{user} -p #{pw} #{@registry}")
      helm_exec("chart pull #{@registry}/#{@chart}:#{version}")
      helm_exec("chart export #{@registry}/#{@chart}:#{version} -d #{dir}")
      helm_exec("package #{dir}/#{@chart} -d #{dir} --version #{version}")
      target_path = "#{dir}/#{@chart}-#{version}.tgz"
      log target_path
      $stdout.write(File.read(target_path))
    end

    def run(argv)
      parse_arg(argv)
      log @action
      case @action
      when "index.yaml"
        gen_index
      when /.*\.tgz\?tag=(.*)/
        fetch_package($1)
      end
    end
  end
end

cli = HelmOci::CLI.new
cli.run(ARGV)
