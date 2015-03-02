--------------------
Instagram Downloader
--------------------

See a user's most popular instagram posts, in order on one simple website.

Run with:

`ruby instagram_downloader.rb -u <USERNAME>`

This will first fetch the raw metadata for all of this user's media.  It will then sort these by decreasing like count (= most popular first), and open an HTML page displaying this user's photos in popularity order.

You can also pass multiple usernames, comma-separated, and they will each spawn their own thread and begin simultaneously fetching.

Pass `-v` to only render the most popular videos.

Assets are saved in a parent directory called `media` which is git ignored, grouped in a directory matching the respective username.

Save your access token in a file called `.access_token` or pass it as an argument.  Find documentation on getting your Instagram `access_token` [here](http://instagram.com/developer/authentication/).

You may need to run `bundle install` before everything works.  [Learn more here](http://bundler.io/).
