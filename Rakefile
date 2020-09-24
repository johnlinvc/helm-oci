desc "build"
task :build do
  Dir.mkdir("tmp") unless File.exists?("tmp")
  system("../mruby/mruby-mac/bin/mrbc -o tmp/helm_oci.c -Bhelm_oci src/helm_oci.rb")
  Dir.mkdir("bin") unless File.exists?("bin")
  system("gcc -std=c99 -I../mruby/mruby-mac/include src/main.c -o bin/helm-oci ../mruby/mruby-mac/build/host/lib/libmruby.a ../mruby/mruby-mac/build/host/mrbgems/mruby-yaml/yaml-0.2.2/build/lib/libyaml.a -lm -lcurl")
end

task :default => [:build]
