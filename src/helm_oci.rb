HELM_BIN = "helm"

class HelmOci
  class CLI
    def helm_exec(cmd, *args)
      full_cmd = "HELM_EXPERIMENTAL_OCI=1 #{HELM_BIN} #{cmd} #{args.join(" ")}"
      log `#{full_cmd}`
    end

    def auth_param
      "#{@user}:#{@pw}"
    end

    def log(*obj)
      $stderr.puts(*obj)
    end

    def query_oci(*paths)
      uri = ["https://#{auth_param}@#{@registry}",*paths].join("/")
      log(uri)
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
          "urls" => ["oci+login://#{auth_param}@#{@repo}/#{chart}-#{tag}.tgz?tag=#{tag}"]
        }
      end
    end

    def gen_index(chart)
      log("gen index for #{chart}")
      versions = get_chart_versions(chart)
      yaml = {"apiVersion" => "v1", "entries" => {chart => versions}}
      yaml_s = YAML.dump(yaml)
      log(yaml_s)
      puts yaml_s
    end

    def parse_arg(argv)
      log(argv)
      @uri = argv[4]
      @uri =~ /^oci\+login:\/\/([^:]+):([^@]+)@(.*)\/([^\/]+)$/
      if !$~
          log("repo format error")
      end
      @user, @pw, @repo, @action = $~.captures
      @repo =~ /^([^\/]+)\/(.+)$/
      if !$~
          log("registry format error")
      end
      @registry, @chart = $~.captures
    end

    def fetch_package(version)
      dir = Dir.mktmpdir
      trap(:EXIT) {
        # TODO(johnlinvc): remove the tmpdir
      }
      log(@chart, version)
      log(dir)
      helm_exec("registry login -u #{@user} -p #{@pw} #{@registry}")
      helm_exec("chart pull #{@registry}/#{@chart}:#{version}")
      helm_exec("chart export #{@registry}/#{@chart}:#{version} -d #{dir}")
      helm_exec("package #{dir}/#{@chart} -d #{dir} --version #{version}")
      target_path = "#{dir}/#{@chart}-#{version}.tgz"
      log target_path
      log $stdout.write(File.read("/var/folders/8s/xxyv93l93z98tnds9_jk5dn537qqvd/T/d20200925-7401-27ceugdzf/nginx-7.0.1.tgz", "rb"))
    end

    def run(argv)
      parse_arg(argv)
      log @action
      case @action
      when "index.yaml"
        gen_index(@chart)
      when /.*\.tgz\?tag=(.*)/
        fetch_package($1)
      end
    end
  end
end

cli = HelmOci::CLI.new
cli.run(ARGV)
