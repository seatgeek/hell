# Hell

An interactive web ui for Capistrano that also provides a json api

![http://cl.ly/image/0R2H1J0t0c35](http://cl.ly/image/0R2H1J0t0c35/s10e11_480.jpg)

## Requirements

- Ruby 1.9.2
- Bundler

## Installation

Simply add `hell` as a dependency in your Gemfile:

	source 'http://rubygems.org'
	source 'http://gems.github.com'

	gem 'hell'

And then run the following in your app directory:

	bundle install

## Usage

Once installed, you'll want to run the `hell` binary:

	hell

Note that if you have multiple capistrano versions installed for multiple repositories, you may need to instead use:

	bundle exec hell

Then open `localhost:4567` in your browser to get an interactive interface around your capistrano recipes.

### Running commands

Hell provides an autocompleted list of all capistrano tasks you have setup, and you can run this against a specific environment as necessary. By default, hell will start the command in the background, and then use an `EventSource` to read the generated logfile.

When you run a task, that task is added to your history so that you may re-read the logs at a later date, as well as re-run the tasks as necessary. This history is done using `localstorage`, and as such is not shared amongst different users of your application.

Note that Hell does not provide persistence of generated tasks, nor does it perform locking of individual tasks. For now, suggest using tools such as [Logstash](http://logstash.net/) to persist the logs, and using locking techniques within your capistrano tooling instead.


### Capistrano as an API

Inspired by Github's internal [Heaven](https://github.com/blog/1241-deploying-at-github) app, Hell provides a simple, rest-like json api around Capistrano. XML-RPC implementation to come.

Available endpoints:

- `/tasks`: List all available tasks
- `/tasks/search/:pattern`: Search for a given, non-regex pattern
- `/tasks/:name/background`: Kicks off the execution of a task in the background and writes the output to a log file. Will respond with an id for future log file recovery.
- `/tasks/:name/exists`: Checks if a task exists
- `/tasks/:name/execute`: Kicks off the execution of a task and responds with the results using the sinatra streaming api. EventSource-compatible.
- `/logs/:id/tail`: Using the id provided by `/tasks/:name/background`, will start a sinatra stream on the log file in question.
- `/logs/:id/view`: Using the id provided by `/tasks/:name/background`, will output the current contents of a logfile. Useful for later recovery of the logs through the web api.

Note that the current response is subject to change, and as such is not documented, though we will attempt to augment rather than change them.

### Configuration

The following environment variables are available for your use:

- `HELL_APP_ROOT`: Path from which capistrano should execute. Defaults to `Dir.pwd`.
- `HELL_REQUIRE_ENV`: Whether or not to require specifying an environment. Default: `1`.
- `HELL_LOG_PATH`: Path to which logs should be written to. Defaults to `Dir.pwd + '/log'`.
- `HELL_BASE_DIR`: Base directory to use in web ui. Useful for subdirectories. Defaults to `/`.
- `HELL_SENTINEL_STRINGS`: Sentinel string used to denote the end of a task run. Defaults to `Hellish Task Completed`.

## TODO

* ~~Finish the execute task so that it sends output to the browser~~
* ~~Figure out where/how to store deploy logs on disk~~
* ~~Blacklist tasks from being displayed~~
* ~~Add support for environment variables~~
* ~~Add support for deployment environments~~
* ~~Add support for ad-hoc deploy callbacks~~
* Save favorite commands as buttons
* Save defaults in a cookie
* Use a slide-up element for task output
* Add optional task locking so that deploys cannot interfere with one-another
* Add ability to use pusher instead of sinatra streaming

## License

Copyright (c) 2012 Jose Diaz-Gonzalez

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
