## Sample
```ruby
[
  { 'kind' => 'sleep', 'value' => 1 }, # wait for some seconds before next command
  { 'kind' => 'wait', 'value' => '#login' }, # delay until #login exists, if not, timeout error (60 secs)
  "$('#loginEmail').val('my_username');",
  "$('#loginPassword').val('my_pass');",
  "$('#submit_sign_in').click()", 
  { 'kind' => 'screenshot' } # print screenshot
]
```