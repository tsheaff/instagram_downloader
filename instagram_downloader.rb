require "net/http"
require "uri"
require "rubygems"
require "json"
require "open-uri"
require "fileutils"
require "shellwords"

# see http://instagram.com/developer/authentication/ to get your access token

stored_token = File.open(".access_token", "rb").read
username = ARGV.fetch(0, '<DEFAULT_USERNAME>')
access_token = ARGV.fetch(1, stored_token)

class PhotoFetcher  
	def initialize(username, access_token)  
		@username = username
		@access_token = access_token

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
		@user_id = blob["data"].first["id"]
	end

	def fetch_media(endpoint = nil)
		endpoint = ('https://api.instagram.com/v1/users/' + @user_id + '/media/recent?count=100&access_token=' + @access_token) if (endpoint == nil)
		blob = response_blob(endpoint)

		media = media_from_blob(blob)
		@all_media.concat(media)
		puts "now has #{@all_media.count} media"

		next_endpoint = next_endpoint(blob)
		if next_endpoint
			fetch_media(next_endpoint)
		else
			puts "fetched all media"
			generate_html
		end
	end

	def generate_html
		puts "generating html"
		sorted_media = @all_media.sort { |a, b| b.like_count <=> a.like_count }

		parent_dir = 'media'
		FileUtils.mkdir(parent_dir) if not File.directory?(parent_dir)
		
		html = ''
		sorted_media.each do |media|
			html += media.html_tag
		end

		html_file_name = parent_dir + '/' + @username + '.html'
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
		@photo_url = data["images"]["standard_resolution"]["url"]
		@width = data["images"]["standard_resolution"]["width"]
		@height = data["images"]["standard_resolution"]["height"]
		@link = data["link"]
		@video_url = data["videos"] != nil ? data["videos"]["standard_resolution"] : nil
		@like_count = data["likes"]["count"]
	end

	def like_count
		@like_count
	end

	def url
		is_photo ? @photo_url : @video_url
	end

	def is_photo
		@photo_url != nil
	end

	def type
		is_photo ? 'photo' : 'video'
	end

	def file_name
		@like_count.to_s.rjust(6, "0") + ' likes   ' + URI(url).path.split('/').last
	end

	def html_tag
		"<img src=\"" + self.url + "\" height=\"" + @height.to_s + "\" width=\"" + @height.to_s + "\" instagram-link=\"" + @link + "\"></img>\n"
	end
end


if username != nil
	fetcher = PhotoFetcher.new(username, access_token)
	fetcher.fetch
end

