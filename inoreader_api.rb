require "digest/md5"

module InoreaderAPI
  class Endpoint < Sinatra::Base
    configure do
      set :database_file, "config/database.yml"

      register Sinatra::ActiveRecordExtension
      ActiveRecord::Base.include_root_in_json = false

      set :api_key, Digest::MD5.hexdigest("inoreader:#{ENV['INOREADER_TOKEN']}")
    end

    def unprotected
      request.path_info.start_with?('/oauth2')
    end

    before do
      return if unprotected
      halt 403 unless authenticated?(env['HTTP_AUTHORIZATION'])

      content_type :json
    end

    after do
      response.body = JSON.dump(response.body)
    end

    def authenticated?(auth_header)
      return unless auth_header
      auth_header.sub('GoogleLogin auth=', '').sub(/bearer\s/i, '').casecmp(settings.api_key).zero?
    end

    def to_long_form(id)
      sprintf("tag:google.com,2005:reader/item/%016x", id)
    end

    def to_short_form(id)
      id.sub('tag:google.com,2005:reader/item/', '').to_i(16)
    end

    get '/subscription/list' do
      subscriptions = FeedRepository.list.map do |feed|
        {
          id: feed.id,
          title: feed.name,
          categories: [],
          sortid: feed.id,
          firstitemmsec: 0,
          url: feed.url,
          htmlUrl: feed.url,
          iconUrl: ''
        }
      end

      {
        subscriptions: subscriptions
      }
    end

    get '/user-info' do
      {
        userId: 0,
        userName: 'Stringer',
        userProfileId: 0,
        userEmail: 'github.com/swanson/stringer',
        isBloggerUser: false,
        signupTimeSec: Time.now.to_i,
        isMultiLoginEnabled: false,
      }
    end

    get '/stream/contents**' do
      stories = StoryRepository.unread

      response = {
        id: "user/1005754933/state/com.google/reading-list",
        title: "Stinger unread"
      }

      unless stories.empty?
        last_updated = stories.max {|a,b| a.updated_at <=> b.updated_at }.updated_at.to_i
        response[:updated] = last_updated
        response[:updatedUsec] = (last_updated * 1000 * 1000).to_s
      end

      if request.path_info.include?('starred')
        response[:items] = []
      else
        response[:items] = stories.map do |story|
          {
            id: to_long_form(story.id),
            categories: [],
            title: story.title,
            published: story.published.to_i,
            updated: story.published.to_i,
            canonical: [{ href: story.permalink }],
            summary: {
              direction: 'ltr',
              content: story.body
            },
            author: '',
            origin: {
              streamId: story.feed.id
            }
          }
        end
      end

      response
    end

    get '/stream/items/ids' do
      stories = StoryRepository.unread

      {
        items: [],
        itemRefs: stories.map do |story|
          {
            id: story.id.to_s,
            directStreamIds: [],
            timestampUsec: (story.updated_at.to_i * 1000 * 1000).to_s
          }
        end
      }
    end

    post '/mark-all-as-read' do
      StoryRepository.fetch_unread_by_timestamp(params['ts']).update_all(is_read: true)
      status 200
    end

    post '/edit-tag' do
      if request.query_string != ''
        ids = CGI::parse(request.query_string)['i']&.map {|id| to_short_form(id) }
      elsif (request_body = request.body.read).size > 0
        ids = CGI::parse(request_body)['i']&.map {|id| to_short_form(id) }
      else
        id_strings = *params['i']
        ids = id_strings&.map {|id| to_short_form(id) }
      end

      if params['a'] == 'user/-/state/com.google/read'
        MarkAllAsRead.new(ids).mark_as_read unless ids.empty?
        halt 200
      elsif params['r'] == 'user/-/state/com.google/read'
        ids.each do |id|
          begin
            MarkAsUnread.new(id).mark_as_unread
          rescue ActiveRecord::RecordNotFound
          end
        end

        halt 200
      end
    end

    get '/tag/list' do
      {
        tags: []
      }
    end

    get '/preference/stream/list' do
      {
        'streamprefs': {}
      }
    end

    get '/oauth2/auth' do
      redirect_uri = params['redirect_uri'] + "?code=stringer&state=#{params[:state]}"
      puts "Redirecting to redirect_uri"

      redirect redirect_uri
    end

    post '/oauth2/token' do
      {
        'access_token': settings.api_key,
        'token_type': 'Bearer',
        'expires_in': 2147483647,
        'refresh_token': settings.api_key,
        'scope': 'read'
      }
    end
  end
end
