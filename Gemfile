source 'https://rubygems.org'

# Specify your gem's dependencies in fluent-plugin-kinesis.gemspec
gemspec

%w[fluentd].each do |lib|
  dep = case ENV[lib]
        when 'stable', nil then nil
        else ENV[lib]
        end
  gem lib, dep
end
