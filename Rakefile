def system_raise(*args)
  system(*args) or exit $?.exitstatus
end

desc "build"
task :build do
  FileUtils.mkdir_p("tmp")
  system_raise("vendor/mruby/bin/mrbc -o tmp/helm_oci.c -Bhelm_oci src/helm_oci.rb")
  FileUtils.mkdir_p("bin")
  system_raise("gcc -std=c99 -Ivendor/mruby/include src/main.c -o bin/helm-oci vendor/mruby/build/host/lib/libmruby.a vendor/mruby/build/host/mrbgems/mruby-yaml/yaml-0.2.2/build/lib/libyaml.a -lm -lcurl")
end

task :release_mac do
  Dir.chdir("vendor") do
    system_raise("git clone https://github.com/mruby/mruby.git mruby") unless Dir.exists?("mruby")
    Dir.chdir("mruby") do
      system_raise("git checkout a97f085c52c3a98ffd26e69ac1fd0d43dc83864c")
      FileUtils.cp("../build_config.rb","./")
      FileUtils.cp("../build_config.rb.lock","./")
    end
  end
  Dir.chdir("vendor/mruby") do
    system_raise("rm -rf build")
    system_raise("rake clean")
    system_raise("rake")
    FileUtils.cp("build_config.rb.lock","../")
  end
  FileUtils.mkdir_p("tmp")
  system_raise("vendor/mruby/bin/mrbc -o tmp/helm_oci.c -Bhelm_oci src/helm_oci.rb")
  bin_path = "build/macos/helm-oci/bin"
  FileUtils.mkdir_p(bin_path)
  system_raise("gcc -std=c99 -Ivendor/mruby/include src/main.c -o #{bin_path}/helm-oci vendor/mruby/build/host/lib/libmruby.a vendor/mruby/build/host/mrbgems/mruby-yaml/yaml-0.2.2/build/lib/libyaml.a -lm -lcurl")
  Dir.chdir("build/macos") do
    system_raise("tar -zvcf helm-oci-macos.tgz helm-oci/")
  end
end

task :docker_release_linux do
  system_raise("docker run --rm -it -v '#{pwd}':/app -w /app ruby:2.7 /bin/bash -c 'rake release_linux'")
end

task :release_linux do
  Dir.chdir("vendor") do
    system_raise("git clone https://github.com/mruby/mruby.git mruby") unless Dir.exists?("mruby")
    Dir.chdir("mruby") do
      system_raise("git checkout a97f085c52c3a98ffd26e69ac1fd0d43dc83864c")
      FileUtils.cp("../build_config.rb","./")
      FileUtils.cp("../build_config.rb.lock","./")
    end
  end
  Dir.chdir("vendor/mruby") do
    system("rm -rf build")
    system_raise("rake clean")
    system_raise("rake")
  end
  FileUtils.mkdir_p("tmp")
  system_raise("vendor/mruby/bin/mrbc -o tmp/helm_oci.c -Bhelm_oci src/helm_oci.rb")
  bin_path = "build/linux/helm-oci/bin"
  FileUtils.mkdir_p(bin_path)
  system_raise("gcc -std=c99 -Ivendor/mruby/include src/main.c -o #{bin_path}/helm-oci vendor/mruby/build/host/lib/libmruby.a vendor/mruby/build/host/mrbgems/mruby-yaml/yaml-0.2.2/build/lib/libyaml.a -lm -lcurl")
  Dir.chdir("build/linux") do
    system_raise("tar -zvcf helm-oci-linux.tgz helm-oci/")
  end
end

task :default => [:build]
