--------------------
Instagram Downloader
--------------------

Run with:

`ruby instagram_downloader.rb '<USERNAME>' '<ACCESS_TOKEN>'`

This will first fetch the raw metadata for all of this user's media.  It will then sort these by decreasing like count (= most popular first), and begin downloading the assets in this order.

Assets are saved in a parent directory called `media` which is git ignored, grouped in a directory matching the respective username.

Find documentation on getting your Instagram `access_token` [here](http://instagram.com/developer/authentication/).
