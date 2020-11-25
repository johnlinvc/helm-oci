HELM_BIN = "helm"
Curl::HTTP_VERSION = Curl::HTTP_1_0

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

    def url_with_auth(*paths)
      ["https://#{auth_param}@#{@registry}",*paths].join("/")
    end

    def extract_next_page(response)
      link = response.headers["Link"]
      return nil unless link
      addr, rel = link.split(";").map(&:strip)
      return nil unless rel == 'rel="next"'
      addr[2...-1]
    end

    def query_oci(*paths)
      next_page = nil
      uri = url_with_auth(*paths)
      log("query_oci uri",uri)
      curl = Curl.new
      response = curl.get(uri)
      json_body = JSON.parse(response.body)
      log(json_body)
      [json_body, extract_next_page(response)]
    end

    def query_all(start_link)
      all_result = []
      log(start_link)
      next_page = start_link
      while next_page
        log("next_page",next_page)
        current_result, next_page = query_oci(next_page)
        all_result.append(current_result)
        log(current_result)
      end
      all_result
    end

    def get_chart_versions(chart, repo, scheme)
      all_pages = query_all("v2/#{chart}/tags/list")
      all_pages.map do |page|
        page["tags"].find_all do |tag|
          tag =~ /^\d+\.\d+\.\d+-?.*/
        end.map do |tag|
          {
            "apiVersion" => "v2",
            "version" => tag,
            "name" => chart,
            "urls" => ["#{scheme}://#{repo}/#{chart}/#{chart}-#{tag}.tgz?tag=#{tag}"]
          }
        end
      end.flatten
    end

    def get_chart_names
      query_all("v2/_catalog").map do |page|
        log page
        page["repositories"]
      end.flatten
    end

    def get_index(repo, charts, scheme)
      scheme ||= "oci+login"
      repo ||= @repo
      charts = get_chart_names unless charts
      entries = charts.map do |chart|
        [chart , get_chart_versions(chart, repo, scheme)]
      end.to_h
      yaml = {"apiVersion" => "v1", "entries" => entries}
      yaml_s = YAML.dump(yaml)
      log(yaml_s)
      yaml_s
    end

    def gen_index
      puts get_index
    end

    def parse_arg(argv)
      log(argv)
      if argv[1] == "--version"
        puts "current version"
        exit 0
      end
      if argv[1] == "proxy"
        puts "Proxy mode"
        @mode = :proxy
        @uri = argv[2]
        @hostname = argv[3]
        @charts = argv.fetch(4,nil).split(",").map(&:strip)
      else
        @mode = :downloader
        @uri = argv[4]
      end
      @uri =~ /^oci\+login:\/\/(.*)\/?([^\/]+)?$/
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

    def package_path(version)
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
    end

    def fetch_package(version)
      $stdout.write(File.read(package_path))
    end

    class Proxy
      def initialize(cli, hostname, charts)
        @cli = cli
        @hostname = hostname
        @charts = charts
      end

      def log(*obj)
        $stderr.puts(*obj) if ENV["HELM_OCI_DEBUG"] == "1"
      end

      def route(env)
        path = env["PATH_INFO"]
        case path
        when /index\.yaml$/
          handle_index
        else
          handle_chart(path)
        end
      end

      def call(env)
        log env
        route(env)
      end

      def handle_index
        body = @cli.get_index(@hostname, @charts, "http")
        [200, { 'Content-Type' => 'application/yaml' }, [body]]
      end

      def handle_chart(path)
      end
    end

    def run_proxy
      app = Proxy.new(self, @hostname, @charts)
      server = SimpleHttpServer.new(
        host: 'localhost',
        port: 8000,
        app: app,
        debug: true
      )
      server.run
    end

    def run_downloader
      log @action
      case @action
      when "index.yaml"
        gen_index
      when /.*\.tgz\?tag=(.*)/
        fetch_package($1)
      end
    end

    def run(argv)
      parse_arg(argv)
      log @mode
      case @mode
      when :proxy
        run_proxy
      when :downloader
        run_downloader
      end
    end
  end
end

cli = HelmOci::CLI.new
cli.run(ARGV)
