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
  { 'kind' => 'wait', 'value' => '#login' }, # delay until #login exists, if not, timeout error
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
Easy Scraper supports for the following commands:
- `string`: performs a js command (include `return` if necessary, sample: `return $('title').text()`)     
  Sample: `$('title').text()`
- `sleep`: waits for some seconds before next command    
  Sample: `{ kind: 'sleep', value: 2 }`
- `wait`: waits until some element exist or selector is accomplished (raises timeout error after 180 seconds)    
  Sample: `{ kind: 'wait', value: "#my_panel a.expected_link" }`
- `screenshot`: takes the screenshot of current page and returns the image     
  Sample: `{ kind: 'screenshot' }`
- `visit`: visits another url     
  Sample: `{ kind: 'visit', value: "http://another_url.com/" }`
- `downloaded`: returns the last downloaded file     
  Sample: `["$('#my_panel a.download_pdf')[0].click()", { kind: 'downloaded' }]`
- `until`: retries until `command` returns some value    
  * value: [String|Hash] Any command that returns a expected value
  * commands: [Array] Array of commands to be performed before performing `value` for each iteration
  * max: [Integer] Maximum iterations before raising Timeout (Default 100)
  Sample: `{ kind: 'until', max: 100, value: "return $('.my_link').text()", commands: "$('#pagination a')[untilIndex].click()" }`

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
- Publish: `docker build -t owencio/easy_scraper . && docker push owencio/easy_scraper:latest`

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

