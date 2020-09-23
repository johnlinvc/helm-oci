HELM_BIN = "helm"

class HelmOci
  class CLI
    def helm_exec(cmd, *args)
      full_cmd = "HELM_EXPERIMENTAL_OCI=1 #{HELM_BIN} #{cmd} #{args.join(" ")}"
      $stderr.puts `#{full_cmd}`
    end

    def gen_index(chart)
      $stderr.puts("gen index for #{chart}")
      versions = [{
        "apiVersion" => "v1",
        "version" => "7.0.1",
        "name" => chart
      }]
      yaml = {"apiVersion" => "v1", "entries" => {chart => versions}}
      yaml_s = YAML.dump(yaml)
      $stderr.puts(yaml_s)
      puts yaml_s
    end

    def parse_arg(argv)
      $stderr.puts(argv)
      uri = argv[4]
      uri =~ /^oci\+login:\/\/([^:]+):([^@]+)@(.*)\/([^\/]+)$/
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
      helm_exec("registry login -u #{@user} -p #{@pw} #{@registry}")
      case @action
      when "index.yaml"
        gen_index(@chart)
      end
    end
  end
end

cli = HelmOci::CLI.new
cli.run(ARGV)
