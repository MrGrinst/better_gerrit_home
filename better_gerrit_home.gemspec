Gem::Specification.new do |s|
  s.name        = "better_gerrit_home"
  s.version     = File.read("VERSION").strip
  s.licenses    = ["MIT"]
  s.summary     = "Host a better version of Gerrit's home page."
  s.authors     = ["Kyle Grinstead"]
  s.email       = "kyleag@hey.com"
  s.files       = Dir.glob("{lib,public}/**/*") + ["Gemfile"]
  s.homepage    = "https://rubygems.org/gems/better_gerrit_home"
  s.metadata    = { "source_code_uri" => "https://github.com/MrGrinst/better_gerrit_home" }
  s.require_path = "lib"
  s.platform    = Gem::Platform::RUBY
  s.executables = ["better_gerrit_home"]
  s.post_install_message = <<MSG

\e[32mThanks for installing better_gerrit_home!\e[0m
\e[32mSet it up by running `\e[0mbetter_gerrit_home --setup\e[32m`\e[0m

MSG
end
