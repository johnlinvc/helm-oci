HELM_BIN = "helm"
Curl::HTTP_VERSION = Curl::HTTP_1_0

class HelmOci
  class CLI
    def helm_exec(cmd, *args)
      full_cmd = "HELM_EXPERIMENTAL_OCI=1 #{HELM_BIN} #{cmd} #{args.join(" ")}"
      res = `#{full_cmd}`
      log(res)
      res
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

    def query_oci_json(*paths, headers: {})
      response = query_oci(*paths, headers: headers)
      json_body = JSON.parse(response.body)
      log(json_body)
      [json_body, extract_next_page(response)]
    end

    def query_oci(*paths, headers: {})
      next_page = nil
      uri = url_with_auth(*paths)
      log("query_oci uri",uri)
      curl = Curl.new
      response = curl.get(uri)
      response
    end

    def query_all(start_link)
      all_result = []
      log(start_link)
      next_page = start_link
      while next_page
        log("next_page",next_page)
        current_result, next_page = query_oci_json(next_page)
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
      entries = charts.map do |chart|
        [chart , get_chart_versions(chart, repo, scheme)]
      end.to_h
      yaml = {"apiVersion" => "v1", "entries" => entries}
      yaml_s = YAML.dump(yaml)
      log(yaml_s)
      yaml_s
    end

    def gen_index(action)
      repo_names = action.split("?")[1]&.split("=")[1]&.split(",")
      log repo_names
      if repo_names
        chart_names = repo_names
      else
        chart_names = get_chart_names
      end
      puts get_index(@repo, chart_names, "oci+login")
    end

    def parse_proxy_arg(argv)
      puts "Proxy mode"
      @mode = :proxy
      @uri = argv[2]
      @hostname = argv[3]
      @charts = argv.fetch(4,nil).split(",").map(&:strip)
      @uri =~ /^oci\+login:\/\/([^\/]*)\/?.*$/
      if !$~
          log("repo format error")
      end
      log $~.captures
      @registry = $~.captures[0]
    end

    def parse_downloader_arg(argv)
      @mode = :downloader
      @uri = argv[4]
      @uri =~ /^oci\+login:\/\/(.*)\/([^\/]+)?$/
      if !$~
          log("repo format error")
      end
      log $~.captures
      @repo, @action = $~.captures
      @repo =~ /^([^\/]+)(\/(.+))?$/
      if !$~
          log("registry format error")
      end
      log $~.captures
      @registry, dontcare, @chart = $~.captures
    end

    def parse_arg(argv)
      log(argv)
      if argv[1] == "--version"
        puts "current version"
        exit 0
      end
      if argv[1] == "proxy"
        parse_proxy_arg(argv)
      else
        parse_downloader_arg(argv)
      end
    end

    def pull_v2(registry, chart, version, dir)
      save_succeed = false
      PULL_RETRY.times do |i|
        log("pull chart: attempt #{i} ")
        chart_identifier="oci://#{registry}/#{chart}"
        helm_exec("pull #{chart_identifier} --version #{version} -d #{dir}")
        if $? == 0
          save_succeed = true
        end
        break if save_succeed
      end
      if !save_succeed
        puts "failed to save chart"
        exit 1
      end
    end

    def pull(chart_identifier, chart, version)
      save_succeed = false
      PULL_RETRY.times do |i|
        log("pull chart: attempt #{i} ")
        helm_exec("chart pull #{chart_identifier}")
        resp = helm_exec("chart list")
        save_succeed = resp.each_line.map{ |l| l.split("\t").map(&:strip) }.any? do |fs|
          fs[1] == chart && fs[2] == version
        end
        break if save_succeed
      end
      if !save_succeed
        puts "failed to save chart"
        exit 1
      end
    end

    def export(chart_identifier, dir)
      export_succeed = false
      EXPORT_RETRY.times do |i|
        log("export chart: attempt #{i} ")
        helm_exec("chart export #{chart_identifier} -d #{dir}")
        if $?==0
          export_succeed  = true
          break
        end
      end
      if !export_succeed
        puts "failed to export chart"
        exit 1
      end
    end

    def check_helm_oci_support
      version = `#{ENV['HELM_BIN']} version --short`
      log(version)
      major,minor,bugfix=version[1..-1].split(".",3)
      log([major,minor,bugfix])
      if [major, minor, bugfix[0]] == %w{3 7 0}
        $stderr.puts("helm 3.7.0 is not supported, please upgrade to 3.7.1 or downgrade to 3.6")
        exit 1
      end
      if major.to_i >= 3 && minor.to_i >= 7
        :v2
      else
        :v1
      end
    end

    TMP_DIR_NAME=".helm_oci_tmp"
    EXPORT_RETRY=5
    PULL_RETRY=5
    def package_path(chart, version)
      dir = "#{Dir.pwd}/#{TMP_DIR_NAME}/#{chart}"
      begin
        FileUtils.mkdir_p(dir)
      rescue Errno::EEXIST
      end
      trap(:EXIT) {
        `rm -rf #{dir}/*`
      }
      log(chart, version)
      log(dir)
      helm_exec("registry login -u #{user} -p #{pw} #{@registry}")
      log(check_helm_oci_support)
      case check_helm_oci_support
      when :v1
        chart_identifier = "#{@registry}/#{chart}:#{version}"
        pull(chart_identifier, chart, version)
        export(chart_identifier, dir)
        log(`ls #{dir}`)
        helm_exec("package #{dir}/#{chart} -d #{dir} --version #{version}")
        log(`ls #{dir}`)
      when :v2
        pull_v2(@registry, chart, version, dir)
      end

      target_path = "#{dir}/#{chart}-#{version}.tgz"
    end

    def fetch_package(version)
      $stdout.write(File.read(package_path(@chart, version)))
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

      def response_404
        [200, { 'Content-Type' => 'application/yaml' }, ["Not Found"]]
      end

      def handle_chart(path)
        path =~ /.*\/([^\/]+)\/([^\/]+).tgz$/
        return response_404 unless $~
        chart, filename_without_ext = $~.captures
        log chart, filename_without_ext
        version = filename_without_ext[(chart.size+1)..-1]
        log version
        file_path = @cli.package_path(chart, version).strip
        log file_path
        f = File.read(file_path)
        log f.size
        [200, { 'Content-Type' => 'application/gzip'}, [f]]
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
      when /index.yaml(\?.*)?/
        gen_index(@action)
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

ARGV.unshift($0)
cli = HelmOci::CLI.new
cli.run(ARGV)
