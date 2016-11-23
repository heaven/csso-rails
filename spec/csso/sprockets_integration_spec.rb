#encoding: utf-8

require 'minitest/autorun'
require 'fileutils'
require 'csso'

# Encoding.default_external = Encoding::UTF_8

describe Csso do

  subject { Csso }
  let(:sprockets_env_without_csso){
    begin
      require 'sprockets'
    rescue LoadError
      skip "Skipping sprockets integration, as there's no sprockets in this env"
    end
    e = Sprockets::Environment.new(File.expand_path('../', File.dirname(__FILE__)))
    e.append_path 'fixtures'
    e.config = e.config.merge(gzip_enabled: false).freeze if e.respond_to? :config
    # e.logger = Logger.new STDOUT
    e
  }
  let(:result_dir){
    d = File.expand_path('../fixtures/res', File.dirname(__FILE__))
    FileUtils.mkdir_p(d)
    d
  }
  let(:manifest_file){
    File.expand_path('manifest.json', result_dir)
  }
  let(:manifest){
    sprockets_env
    Sprockets::Manifest.new(sprockets_env, result_dir, manifest_file)
  }
  let(:sprockets_env){
    subject.install(sprockets_env_without_csso)
    sprockets_env_without_csso
  }

  it "installs" do
    sprockets_env.css_compressor.must_equal Csso::Compressor
    manifest.environment.must_equal(sprockets_env)
    manifest.clobber
    res = manifest.compile('test.css')
    res.size.must_equal 1
    [File.expand_path('../../fixtures/test.css', __FILE__), 'test.css'].must_include res.first
    File.read(manifest_file).wont_equal '{}'
    sprockets_env['test.css'].source.must_equal '.class{color:red}'
    manifest.clobber
  end

  it "compiles with sourcemap" do
    manifest.clobber
    begin
      require 'sass'
    rescue LoadError
      skip 'No sass in this env, skipping'
    end
    manifest.compile('test2.css')
    manifest.compile('test2.css.map')
    json = JSON.load File.read(manifest_file)
    json["assets"]["test2.css"].must_match(/\.css$/)
    sprockets_env['test2.css'].source.must_equal '.class,.class .other_class{color:red}.something{color:#000}.test2{color:#00f}'
    map = JSON.load(sprockets_env['test2.css.map'].source)
    map["sources"].size.must_equal 4
    manifest.clobber
  end

  it "loads into rails" do
    begin
      require "rails"
    rescue LoadError
      skip "no rails in this env"
    end
    require "sprockets/railtie"
    require 'csso/railtie'

    app = Class.new(Rails::Application) do
      config.eager_load = false
      config.assets.enabled = true
    end
    app.initialize!
    app.config.assets.css_compressor.must_equal :csso
    app.assets.css_compressor.must_equal Csso::Compressor
  end
end
