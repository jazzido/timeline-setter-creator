# encoding: utf-8
require 'fileutils'
require 'securerandom'
require 'json'
#require 'tempfile'
require 'csv'

require 'cuba'
require 'cuba/render'
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
Cuba.use Rack::Static, root: 'public', urls: ["/css", "/js", "/timelines"]

DEFAULT_OPTIONS = {
  :interval => ''
}

def generate_timeline(csv, options={})
  events = TimelineSetter::Parser.new csv
  options.merge!(DEFAULT_OPTIONS)
  TimelineSetter::Timeline.new(:events => events.events,
                               :interval => options[:interval]).timeline
end

def generate_from_hash(h)
  events = h
  csv_string = CSV.generate do |csv|
    csv << ["date", "display_date", "description", "link", "series", "html"]
    events.each do |event|
      csv << [
              event['date'],
              event['display_date'],
              event['description'],
              event['link'],
              event['series'],
              event['html']
             ]
    end
  end
  generate_timeline csv_string
end

Cuba.define do

  on get do
    on root do
      res.write view('index.html')
    end

    on 'preview' do
      h = JSON.parse(req.params['json'])
      if h.size < 2
        res.write "Can't preview. Please create at least 2 valid events'"
      else
        res.write generate_from_hash h
      end


    end

    on 'timeline' do
      res.write view('timeline.html', timeline_url: req.params['timeline'])
    end

  end

  on post do
    on 'timeline' do
      timeline_html = if req.params['file'] # upload
                        generate_timeline req.params['file'][:tempfile].read
                      elsif req.params['json'] # json from manual input interface
                        generate_from_hash JSON.parse(req.params['json'])
                      else
                        raise 'bad request'
                      end

      outdir = File.join('public/timelines', SecureRandom.uuid)
      FileUtils.mkdir_p(outdir)
      timeline_path = File.join(outdir, 'timeline.html')
      File.open(timeline_path, 'w') { |f| f.write timeline_html }

      res.redirect "/timeline?timeline=#{timeline_path.gsub(/^public\//, '')}"
    end
  end
end
