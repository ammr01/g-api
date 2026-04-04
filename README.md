# g-api

**Bash Library To Make Google APIs Easy**

> *“Using google api in bash become easier than python.”*
> — Author: Amr Alasmer

---

## What is this?

`g-api` is a bash library that handles authentication of OAuth 2.0 google APIs, and also handles API requests.

---

## Dependencies


* `bash`
* `curl`
* `php`
* `coreutils 'cat,rm,env,mktemp,mkfifo,dirname,sleep,ps'`


---

## Setup Google

to use this library, you must setup your google account, and enable APIs, to setup google, follow the instructions in: <br>
https://github.com/ammr01/g-api/blob/main/setup-google.md

---

## How it Works

This library provide functions to deal with google APIs, to deal with any API, you first need an access token. <br><br>
So the function get_access_token will provide the access token no matter if you authenticated before, or not. <br><br>
If you are not authenticated before, it will read the client secret file 'json file installed by these steps <br> 
https://github.com/ammr01/g-api/blob/main/setup-google.md'. <br><br>
It will start a local php server, that runs a php code that will handle the received code, and write it to <br>
named pipe, the library will be waiting already on that pipe. <br> <br>
And after gaining the code, the php server will be killed, and then the library will ask for access/refresh <br>
tokens, and stores the json response as file `token.json` in the current working directory 'in the future i will <br>
add posibality to select directory instead of current working directory limitation, but for now it is not that <br> 
bad limitation for me'. <br><br>
Now you are authenticated and have your access token, you can send APIs requests, but if the access token is expire <br>
the library will detect and hadle this by refresh your access token. <br><br>
You can use functions like `read_sheet_range` 'which i didn't write it yet, but in the near future' to read <br>
data from sheet range if you have access token, and appropriate permissions/scopes.<br><br> 
This library is dealing heavily with json, so for json parsing, i used my json-parser-hm, is a json-parser that <br> 
fully written in bash, and stores output in associative arrays 'hash maps'. <br> 

---




## Examples

To use this library you should source it in your bash script, example:

```bash
source g-api.sh

get_access_token
access_token="$OUTPUT"




local EMAIL="To: tst@outlook.com
From: tst@gmail.com
Subject: test
Content-Type: text/html; charset=\"UTF-8\"

<br>TST message that will be stored in the draft  <br>"

local RAW=$(printf "%s" "$EMAIL" | base64 -w0 | tr '+/' '-_' | tr -d '=')




# gurl is only curl wrapper, you can use curl instead only by replacing gurl with curl  
gurl  -X POST \
-H "Authorization: Bearer $access_token" \
-H "Content-Type: application/json" \
-d "{
        \"message\": {
        \"raw\": \"$RAW\"
        }
    }" \
"https://gmail.googleapis.com/gmail/v1/users/me/drafts" && { declare -p | grep "JSON_OUTPUT"; }


```

the example will source the library, and the get an access token, then send request to gmail API<br>
and it asks it to create a new draft.


---


## License

This project is licensed under the **GNU General Public License v3 or later**.

---


## Author

**Amr Alasmer**
