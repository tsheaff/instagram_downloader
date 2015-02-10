require "net/http"
require "uri"
require "rubygems"
require "json"
require "open-uri"
require "fileutils"
require "shellwords"

# see http://instagram.com/developer/authentication/ to get your access token

username = ARGV.fetch(0, '<DEFAULT_USERNAME>')
access_token = ARGV.fetch(1, '<DEFAULT_ACCESS_TOKEN>')

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
			save_media_assets
		end
	end

	def save_media_assets
		photo_count = @all_media.count

		sorted_media = @all_media.sort { |a, b| b.like_count <=> a.like_count }

		parent_dir = 'media'
		FileUtils.mkdir(parent_dir) if not File.directory?(parent_dir)

		dir_name = parent_dir + '/' + @username
		FileUtils.rm_rf(dir_name)
		FileUtils.mkdir(dir_name)
		
		sorted_media.each_with_index do |media, index|
			begin
				file_name = dir_name + '/' + media.file_name[0, 100]
				File.open(file_name, 'wb') do |output_file|
					output_file.write open(media.url).read 
				end
				puts "fetched photo #{index + 1} of #{photo_count}"
			rescue
				puts "could not download media #{media.url}"
			end
		end
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
		@video_url = data["videos"] != nil ? data["videos"]["standard_resolution"] : nil
		@like_count = data["likes"]["count"]
	end

	def like_count
		@like_count
	end

	def url
		(@photo_url != nil) ? @photo_url : @video_url
	end

	def file_name
		@like_count.to_s.rjust(6, "0") + ' likes   ' + URI(url).path.split('/').last
	end
end


if username != nil
	fetcher = PhotoFetcher.new(username, access_token)
	fetcher.fetch
end

