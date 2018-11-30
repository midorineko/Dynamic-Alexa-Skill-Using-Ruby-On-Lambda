require 'json'
require 'open-uri'
require 'rss'
REQUEST_TYPES = {
    'LaunchRequest'       => :launch,
    'IntentRequest'       => :intent,
    'SessionEndedRequest' => :end
}

class AlexaResponse

  def initialize(session)
    @session = session
  end

  def to_json
    @response.to_json
  end

  def none
    build_response({ :end_session => true })
  end

  # quick helpers
  def speak_text(text, end_sess = true, attribute_obj = {})
    build_response(self.class.speech_options(text))
    if !end_sess
        @response['response']['shouldEndSession'] = false
    end
    attribute_obj.each do |k,v|
        @response['sessionAttributes'][k] = v
    end
    self
  end
  
  def speak_ssml(ssml)
    build_response(self.class.speech_options(nil, ssml))
    self
  end
  def play_mp3(url)
    build_response(self.class.mp3_options(url))
    self
  end

  def with_card(card)
    add_card({:card => card})
    self
  end

  def with_reprompt(reprompt)
    add_reprompt({:reprompt => reprompt})
    self
  end

  # use these to build the options for reprompt arg or card arg
  def self.speech_options(text, ssml = nil)
    text ? { :text=>text } : { :ssml=>ssml }
  end

  def self.mp3_options(url)
    {:ssml => "<speak><audio src=\"#{url}\" /></speak>"}
  end

  def self.card_options(card_title, card_content, image_small = nil, image_large = nil)
    { :card_title => card_title,
      :card_content => card_content,
      :image_small =>  image_small,
      :image_large => image_large }
  end

  # details
  def build_response(options)
    @response = { 'version': '1.0' }
    add_session(options)
    add_response(options)
    self
  end

  def add_session(options)
    @response['sessionAttributes'] = @session.attributes || {}
  end

  def add_response(options)
    @response['response'] = {
      'shouldEndSession': options.nil? || options[:end_session].nil? ? true : !!options[:end_session]
    }
    add_output(options)
    add_card(options)
    add_reprompt(options)
  end

  def add_output(options)
    @response['response']['outputSpeech'] = self.class.speech(options)
  end

  def add_card(options)
    if options[:card]
      @response['response']['card'] = self.class.card(options)
    end
  end

  def add_reprompt(options)
    if options[:reprompt]
      @response['response']['shouldEndSession'] = false
      @response['response']['reprompt'] = { 'outputSpeech': speech(options[:reprompt]) }
    end
  end

  def self.speech(options)
    if options[:ssml]
      {
        'type': 'SSML',
        'ssml': options[:ssml]
      }
    else
      {
        'type': options[:type] || 'PlainText',
        'text': options[:text]
      }
    end
  end

  def self.card(options)
    card = {
      'type': options[:card_type] || 'Simple',
      'title': options[:card_title] || 'Card Title',
      'content': options[:card_content] || 'Card Contents'
    }
    if options[:image_small] && options[:image_large]
      card.merge!({
        'type' => 'Standard',
        'image' => {
          'smallImageUrl' => options[:image_small],
          'largeImageUrl' => options[:image_large],
        }
      })
    end
    card
  end
end

class DotaRssParser
    def get_titles(user_ag, start_val = 0, static = false)
        rss_results = []
        rss = RSS::Parser.parse(open('http://www.ruby-lang.org/en/feeds/news.rss', 'User-Agent' => user_ag).read, false).items[start_val..start_val+4].to_a
        if static
            rss = RSS::Parser.parse(open('https://www.reddit.com/r/dota2/.rss?format=xml', 'User-Agent' => user_ag).read, false).items[start_val..static-1].to_a
        end
        rss.each_with_index do |result, result_i|
            res_ind = (start_val + result_i + 1).to_s
            final_result = res_ind + ") " + result.title.to_s
            rss_results.push(final_result)
        end
        return rss_results = rss_results.join(". ").gsub("<title>","").gsub("</title>","")
    end
end

def lambda_handler(event:, context:)
    def smart_hash(h)
      h = Hash[h.map{|k,v| [k, v.is_a?(Hash) ? smart_hash(v) : v]}]
      h.instance_eval do
        def method_missing(name, *args, &block)
          self[name.to_s]
        end
      end
      h
    end
     # redefine this in your class, only one class per process
    @application_id_check = 'amzn1.ask.skill.[YOUR ID HERE]'
    @validate_application_on_every_request = true
  
    def handler(event)
      @event = smart_hash(event)
      @version = @event.version
      parse_session
      parse_request
      dispatch_session
      dispatch_response
    end
  
    def parse_session
      @session = @event.session
      @new_session = @session.new
      @session_id = @session.sessionId
      @application_id = @session.application.applicationId
      @session_attributes = @session.attributes || {}
      @user_id = @session.user.userId
      @access_token = @session.user.accessToken
    end
  
    def parse_request
      @request = @event.request
      @request_type = REQUEST_TYPES[@request.type]
      @request_id = @request.requestId
      @intent = @request_type == :intent ? @request.intent.name.sub(/\./,'_') : @request_type
      p "Intent: " + @intent.to_s
    end
  
    def dispatch_session
      on_new_session if @new_session
    end
  
    def dispatch_response
      validate_application_id if @validate_application_on_every_request
      @response = AlexaResponse.new(@session)
      send("on_#{@intent}", @response)
    end
  
    # override these
    def on_new_session(); end
    def on_launch(response)
      set_step = 0;
      if @session_attributes['step']
          set_step = @session_attributes['step'] + 5
      end
      drp = DotaRssParser.new
      got_titles = drp.get_titles(@request_id, set_step)
      response.speak_text(got_titles, false, {'step': set_step})
    end
    def on_next(response)
      set_step = 0;
      if @session_attributes['step']
          set_step = @session_attributes['step'] + 5
      end
      drp = DotaRssParser.new
      got_titles = drp.get_titles(@request_id, set_step)
      response.speak_text(got_titles, false, {'step': set_step})
    end
    def on_static(response)
      drp = DotaRssParser.new
      vals = @request.intent.slots.number.value.to_i rescue 5
      got_titles = drp.get_titles(@request_id, 0, vals)
      response.speak_text(got_titles, true)
    end
    def on_exit(response)
      response.speak_text("see ya!")
    end
    def on_end(response)
      response.speak_text("see ya!")
    end
    def on_AMAZON_FallbackIntent(response)
      response.speak_text("something went wrong please invoke again", true)
    end
    def on_AMAZON_CancelIntent(response)
      response.speak_text("see ya!")
    end
    def on_AMAZON_HelpIntent(response)
      text = "Welcome to Dota 2 RSS Feed. I will read off the top five headlines then you can say continue or next to get the next five. If you only want a certain amount of headlines you can add first and a number to the invoke. Say 'next' to get the first 5 articles or help to hear this again."
      response.speak_text(text, false)
    end
    def on_AMAZON_StopIntent(response)
      response.speak_text("see ya!")
    end
  
    def validate_application_id
      raise "AppID #{@application_id} does not match" if @application_id != @application_id_check
    end
    handler(event)
end
