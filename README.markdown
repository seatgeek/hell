# Hell

An api wrapper around Capistrano

![http://cl.ly/image/0R2H1J0t0c35](http://cl.ly/image/0R2H1J0t0c35/s10e11_480.jpg)

## Requirements

- Ruby 1.9.2
- Bundler

## Installation

In the `hell` directory:

	bundle install

Hell will need access to the gems you use within your app, so you may need to modify the Gemfile to match your own.

## Usage

In the `hell` directory:

	bundle exec rackup config.ru

Then open `localhost:4567/tasks` in your browser to get a listing of all tasks.

Available endpoints:

- `/tasks`: List all available tasks
- `/tasks/search/:pattern`: Search for a given, non-regex pattern
- `/tasks/:name/exists`: Checks if a task exists
- `/tasks/:name/execute`: Kicks off the execution of a task

## TODO

* ~~Finish the execute task so that it sends output to the browser~~
* ~~Figure out where/how to store deploy logs on disk~~
* ~~Blacklist tasks from being displayed~~
* Add support for environment variables
* ~~Add support for deployment environments~~
* ~~Add support for ad-hoc deploy callbacks~~
* Save favorite commands as buttons
* Save defaults in a cookie
* Use a slide-up element for task output

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
