# Easy scrapper
Permits to scrap any website using css selectors to perform commands and retrieve any text value, screenshot or downloaded file.    
Note: You can use jQuery selectors to perform a js command (Auto added jQuery if site does not include)

## API
Easy Scraper supports for the following commands:
- `string`: performs a js command
  `$('title').text()`
- `sleep`: waits for some seconds before next command    
  `{ kind: 'sleep', value: 2 }`
- `wait`: waits until some element(s) exist (raises timeout error after 180 seconds)    
  `{ kind: 'wait', value: "$('#my_panel a.expected_link')" }`
- `screenshot`: takes the screenshot of current page     
  `{ kind: 'screenshot' }`
- `visit`: visits another url     
  `{ kind: 'visit', value: "http://another_url.com/" }`
- `downloaded`: returns the last downloaded file     
  `["$('#my_panel a.download_pdf')[0].click()", { kind: 'downloaded' }]`
- `until`: retries until `command` returns some value    
  * value: [String|Hash] Any command that returns a expected value
  * commands: [Array] Array of commands to be performed before performing `value` for each iteration
  * max: [Integer] Maximum iterations before raising Timeout
  `{ kind: 'until', max: 100, value: "$('.my_link').innerText", commands: "$('#pagination a')[untilIndex].click()" }`

Note: It returns the value of the last command.
  
## Usage 
```ruby
require 'uri'
require 'net/http'

commands = [
  { 'kind' => 'wait', 'value' => '#login' }, # delay until #login exists, if not, timeout error (60 secs)
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

## Example (using browser)
- Page to scrap: `http://google.com`
- Text to search: `Hello world`
- Decomposed commands: `["$('[name=\\'q\\\']').val('Hello world')", "$('input[name=\\\'btnK\\\']')[0].click()",{"kind":"screenshot"}]`
- Visit in your browser `http://localhost:9494/?url=https%3A%2F%2Fwww.google.com%2F&commands=%5B%22%24%28%27%5Bname%3D%5C%5C%27q%5C%5C%5C%27%5D%27%29.val%28%27Hello%20world%27%29%22%2C%20%22%24%28%27input%5Bname%3D%5C%5C%5C%27btnK%5C%5C%5C%27%5D%27%29%5B0%5D.click%28%29%22%2C%7B%22kind%22%3A%22screenshot%22%7D%5D



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/owen2345/easy_scraper

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

