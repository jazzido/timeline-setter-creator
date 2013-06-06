require 'fileutils'
require 'securerandom'

require 'cuba'
require 'cuba/render'
require 'httparty'
require 'timeline_setter'

# hack into TimelineSetter, we need to change their layout template
TMPL = <<-eot
<!DOCTYPE html>
<html>
  <head>
    <link href="/css/timeline-setter.css" rel="stylesheet" />
    <script src="/js/jquery-2.0.2.js"></script>
    <script src="/js/underscore-min.js"></script>
    <script src="/js/timeline-setter.js"></script>
  </head>
  <body style="height: 100%">
    <%= timeline_markup %>
  </body>
</html>
eot

module TimelineSetter
  class Timeline
    def timeline
      ERB.new(TMPL).result(binding)
    end
  end
end


Cuba.plugin Cuba::Render
Cuba.use Rack::Static, root: 'static', urls: ["/css", "/js", "/timelines"]

DEFAULT_OPTIONS = {
  :interval => ''
}

def generate_timeline(path_to_csv, options={})
  sheet = File.open(path_to_csv).read
  events = TimelineSetter::Parser.new sheet
  options.merge!(DEFAULT_OPTIONS)
  html = TimelineSetter::Timeline.new(:events => events.events,
                                      :interval => options[:interval]).timeline


  # FileUtils.mkdir_p outdir unless File.exists? outdir
  # File.open(File.join(outdir, 'timeline.html'), 'w+') do |doc|
  #   doc.write html
  # end

end

def get_csv(url)
  r = HTTParty.get(url)
  raise 'not csv' unless r.headers['content-type'].include?('csv')

end

Cuba.define do

  on get do
    on root do
      res.write view('index.html')
    end

    on 'timeline' do
      res.write view('timeline.html', timeline_url: req.params['timeline'])
    end
  end

  on post do
    on 'new' do
      timeline_html = if req.params['file'] # upload
                        generate_timeline req.params['file'][:tempfile].path
                      elsif req.params['url'] # link
                        begin
                          csv_path = get_csv(req.params['url'])
                        rescue

                     end
                      else
                        raise 'bad request'
                      end

      outdir = File.join('static/timelines', SecureRandom.uuid)
      FileUtils.mkdir_p(outdir)
      timeline_path = File.join(outdir, 'timeline.html')
      File.open(timeline_path, 'w') { |f| f.write timeline_html }

      res.redirect "/timeline?timeline=#{timeline_path.gsub(/^static\//, '')}"
    end
  end
end
