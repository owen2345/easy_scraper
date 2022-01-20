# Easy scrapper
Permits to scrap any website using css selectors to perform commands and retrieve any text value, screenshot or downloaded file.    
Note: You can use jQuery selectors to perform a js command (Auto added jQuery if site does not include)

## Installation
- Docker: `docker pull owencio/easy_scraper && docker run -it  -p 9494:9494 owencio/easy_scraper` ==> `Listening on http://0.0.0.0:9494`
- Docker compose:
  ```yaml
    scraper:
      image: owencio/easy_scraper
      ports:
        - 9494:9494
  ```
      
## Usage 
The request can be done using GET or POST
```ruby
require 'uri'
require 'net/http'

commands = [
  { 'kind' => 'wait', 'value' => "return $('#login')" }, # delay until #login exists, if not, timeout error
  "$('#loginEmail').val('my_username');", # Enter value to a field
  "$('#loginPassword').val('my_pass');", # Enter value to a field
  "$('#submit_sign_in').click()", # submit sign in form
  { 'kind' => 'sleep', 'value' => 1 }, # wait for some seconds before next command
  { 'kind' => 'screenshot' } # print screenshot (Always returns the value of the last command)
]

uri = URI('http://localhost:9494/')
res = Net::HTTP.post_form(uri, url: 'http://my_website.com/signin', commands: commands) # can be GET or POST request
puts res.body  if res.is_a?(Net::HTTPSuccess) # should print image content
```

## API

### Params
- `url`: (String) Url to be visited
- `commands`: (Array) Array of commands
- `session_id`: (String, default null) permit to keep open visited browser and reuse it if available
- `timeout`: (integer, default 180) default timeout when waiting for results
- `logs`: (boolean, default true) permit to disable logs
- `cookies`: (Hash, default nil)
    * domain (String) cookies domain name
    * url (String, default visited url) site url where to define the cookies (must match with domain)
    * values (Hash) cookie values, sample: { "my_attr" => "my value" }

### Commands
Easy Scraper supports for the following commands:
- `string`: performs a js command (include `return` if necessary, sample: `return $('title').text()`)     
  Sample: `$('title').text()`

- `sleep`: waits for some seconds before next command    
  Sample: `{ kind: 'sleep', value: 2 }`

- `wait`: waits until value is accomplished (raises timeout error after 180 seconds by default)        
  * value: [String] Js code that  returns any value to stop waiting
  * timeout: [Integer, optional] Defines the timeout in seconds
  * rescue: [String, optional] Command to be executed when time out (Default raise error)
  Sample: `{ kind: 'wait', value: "return $('#my_panel a.expected_link')[0]" }`

- `screenshot`: takes the screenshot of current page and returns the image         
  * value: [String, optional] name of the screenshot     
  * html: [Boolean, optional] if true saves the current html code     
  Sample: `{ kind: 'screenshot', value: 'name_of_picture', html: true }`

- `visit`: visits another url     
  Sample: `{ kind: 'visit', value: "http://another_url.com/" }`

- `downloaded`: returns the last downloaded file     
  Sample: `["$('#my_panel a.download_pdf')[0].click()", { kind: 'downloaded' }]`

- `values`: process several commands and returns its values (JSON format). Returns the last value if multiple sub commands is provided         
  Sample: `{ kind: 'values', value: ["$('#my_field').text()", ["$('#my_link').click()", "$('#my_field2').text()"]] }`    
  Will return `['val 1', 'val 2']`     
  Note: if one of the values is a file format, it will be parsed into base64 format, sample: `["res 1", "base64:...."]`

- `run_if`: returns the last downloaded file     
  Sample: `{ kind: 'run_if', value: "return $('#my_field')[0] ? nil : true", commands: ["$('#my_field').text()"] }`     
  Commands will be preformed if `#my_field` does not exist  

- `until`: retries until `command` returns some value    
  * value: [String|Hash] Any command that returns a expected value
  * commands: [Array] Array of commands to be performed before performing `value` for each iteration
  * max: [Integer, optional] Maximum iterations before raising Timeout (Default 100)
  * rescue: [String, optional] Command to be executed when time out (Default raise error)
  Sample: `{ kind: 'until', max: 100, value: "return $('.my_link').text()", commands: ["$('#pagination a')[untilIndex].click()"] }`

- `jquery`: adds jquery to the page for easier js selectors (by default added the first page visited)     
  Sample: `{ kind: 'jquery' }`

Note: It returns the value of the last command.

## Example (using browser)
### Sample 1
- Page to scrap: `http://google.com`
- Text to search: `Hello world`
- Decomposed commands: `["$('[name=\\'q\\\']').val('Hello world')", "$('input[name=\\\'btnK\\\']')[0].click()",{"kind":"screenshot"}]`
- Visit in your browser `http://localhost:9494/?url=https%3A%2F%2Fwww.google.com%2F&commands=%5B%22%24%28%27%5Bname%3D%5C%5C%27q%5C%5C%5C%27%5D%27%29.val%28%27Hello%20world%27%29%22%2C%20%22%24%28%27input%5Bname%3D%5C%5C%5C%27btnK%5C%5C%5C%27%5D%27%29%5B0%5D.click%28%29%22%2C%7B%22kind%22%3A%22screenshot%22%7D%5D
- Result:
  ![Image 1](docs/img1.png)

### Sample 2 (Print google.com title)
- Decomposed command: `return $('title').text()`
- Visit in your browser `http://localhost:9494/?url=https%3A%2F%2Fwww.google.com%2F&commands=return%20%24%28%27title%27%29.text%28%29


Note: GET method must pass url encoded values



## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/owen2345/easy_scraper
- Clone repository
- Run app locally: `docker-compose up web` ==> `Listening on http://0.0.0.0:9494
- Run test: `docker-compose up test`
- Publish: 
```
  docker build -t owencio/easy_scraper:0.11 . && docker push owencio/easy_scraper:0.11
  docker tag owencio/easy_scraper:0.11 owencio/easy_scraper:latest 
  docker push owencio/easy_scraper:latest
```

## TODO
- parallel requests pics and removes the wrong downloads
- Download files to a specific folder and improve auto clean up
- Restore the ability to pass custom driver options, such as proxy settings
- Fix `chrome not reachable` test

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

