require "net/http"
require "optparse"
require "uri"
require "rubygems"
require "json"
require "open-uri"
require "fileutils"
require "shellwords"
require "time"

class PhotoFetcher  
	def initialize(username, access_token, only_video, chronological_order, limit)
		@username = username
		@access_token = access_token
		@only_video = only_video
		@chronological_order = chronological_order
		@limit = (limit != nil) ? limit : -1

		@all_data = []
		@all_media = []
		@user_id = ''
	end

	def fetch
		fetch_user_id
		fetch_media
	end
  
	def fetch_user_id
		endpoint = 'https://api.instagram.com/v1/users/search?q=' + @username + '&access_token=' + @access_token
		blob = response_blob(endpoint)
		@user_id = blob["data"].select{ |u| u["username"] == @username }.first["id"]
		puts "@user_id is #{@user_id}"
	end

	def fetch_media(endpoint = nil)
		endpoint = ('https://api.instagram.com/v1/users/' + @user_id + '/media/recent?count=100&access_token=' + @access_token) if (endpoint == nil)
		blob = response_blob(endpoint)

		media = media_from_blob(blob)

		puts "now has #{media.count} media for #{@username}"

		threads = []
		media.each do |instagram_media|
			threads << Thread.new do
				instagram_media.fetch_and_save_photo("/Users/tylersheaffer/Desktop/#{@username}/")
			end
		end
		threads.each do |thread| thread.join end

		# @all_media.concat(media)
		@all_data.concat(blob["data"])

		next_endpoint = next_endpoint(blob)
		if next_endpoint
			fetch_media(next_endpoint)
		else
			puts "fetched all media"
			File.open("/Users/tylersheaffer/Desktop/#{@username}/all_metadata.json", 'w') do |f|
				f.write(@all_data.to_json)
			end
		end
	end

	def generate_html
		puts "generating html"

		sorted_media = @all_media
		if !@chronological_order
			sorted_media = @all_media.sort { |a, b| b.like_count <=> a.like_count }
		end
		sorted_media = sorted_media.select { |a| !@only_video || !a.is_photo }
		if @limit > 0
			sorted_media = sorted_media.first(@limit)
		end

		parent_dir = 'media'
		FileUtils.mkdir(parent_dir) if not File.directory?(parent_dir)
		
		html = ''
		javascript = ''
		sorted_media.each do |media|
			html += media.html
			javascript += media.javascript
		end
		html += "<script>\n" + javascript + "\n</script>"

		html_file_name = parent_dir + '/' + @username + (@only_video ? '-videos' : '') + (@chronological_order ? '-chron' : '') + '.html'
		FileUtils.touch(html_file_name)
		File.open(html_file_name, 'w') do |file|
			file.write(html)
		end

		`open #{html_file_name}`
	end

	def response_blob(endpoint)
		uri = URI.parse(endpoint)
		response = Net::HTTP.get_response(uri)
		JSON.parse(response.body)
	end

	def media_from_blob(blob)
		data = blob["data"]
		data.map { |datum| 
			InstagramMedia.new(datum)
		}
	end

	def next_endpoint(blob)
		blob["pagination"]["next_url"]
	end
end


class InstagramMedia  
	def initialize(data)
		video_info = data["videos"] != nil ? data["videos"]["standard_resolution"] : nil
		photo_info = data["images"]["standard_resolution"]
		@date_created = Time.at(data["created_time"].to_i).utc.iso8601
		@is_photo = (video_info == nil)
		@media_info = @is_photo ? photo_info : video_info

		@url = @media_info["url"]
		@width = @media_info["width"]
		@height = @media_info["height"]

		@url.sub!('scontent-a.cdninstagram', 'scontent-a-sjc.cdninstagram')
		@url.sub!('scontent-b.cdninstagram', 'scontent-b-sjc.cdninstagram')
		@url.sub!('scontent-c.cdninstagram', 'scontent-c-sjc.cdninstagram')

		@link = data["link"]
		@like_count = data["likes"]["count"]
	end

	def fetch_and_save_photo(parent_dir)
		file_type = File.extname(URI.parse(@url).path)
		file_name = @date_created.gsub(":","_") + file_type
		puts "fetching #{file_name}"
		open(parent_dir + file_name, 'wb') do |file|
			file << open(@url).read
		end
	end

	def like_count
		@like_count
	end

	def is_photo
		@is_photo
	end

	def unique_id
		URI(@url).path.split('/').last.split('.').first
	end

	def html_tag
		@is_photo ? "img" : "video"
	end

	def html_video
		"<button id=\"button-" + unique_id + "\" link=\"" + @link + "\">\n" +
		"	<video id=\"" + unique_id + "\" height=\"" + @height.to_s + "\" width=\"" + @width.to_s + "\" loop>\n" +
		"	  <source src=\"" + @url + "\" type=\"video/mp4\">\n" +
		"	</video>\n" +
		"</button>"
	end

	def html_img
		"<a href=\"" + @link + "\" target=\"_blank\">" + 
		"  <img src=\"" + @url + "\" height=\"" + @height.to_s + "\" width=\"" + @height.to_s + "\"></img>\n" +
		"</a>"
	end

	def html
		(@is_photo ? html_img : html_video)
	end

	def javascript
		if @is_photo
			return ''
		end

		"document.getElementById('button-" + unique_id + "').onclick = function () {\n" +
		"	videoElement = document.getElementById('" + unique_id + "');\n" +
		"	if (videoElement.currentTime > 0 && !videoElement.paused && !videoElement.ended) {\n" +
		"		videoElement.pause();\n" +
		"	} else {\n" +
		"		videoElement.play();\n" +
		"	}\n" +
		"};\n" +
		"document.getElementById('button-" + unique_id + "').ondblclick = function () {\n" +
		"	var win = window.open('" + @link + "', '_blank');\n" +
		"	win.focus();\n" +
		"};\n"
	end
end

def fetch_all(username, only_video, chronological_order, limit, access_token)
	username = username.strip
	fetcher = PhotoFetcher.new(username, access_token, only_video, chronological_order, limit)
	fetcher.fetch
end

options = {}
OptionParser.new do |opts|
	opts.on("-v", "--video") { options[:videos] = true }
	opts.on("-c", "--chron") { options[:chronological] = true }
	opts.on("-lLIMIT", "--limit=LIMIT") do |limit|
        options[:limit] = limit.to_i
    end
  	opts.on("-u USERNAMES", "--username USERNAMES", Array, "usernames") do |usernames|
		options[:usernames] = usernames
  	end
end.parse!

access_token = File.open(".access_token", "rb").read

threads = []
options[:usernames].each do |username|
	threads << Thread.new do
		fetch_all(username, options[:videos], options[:chronological], options[:limit], access_token)
	end
end
threads.each do |thread| thread.join end
