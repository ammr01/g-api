#!/bin/bash
# Author : amr
# OS : Debian 13 x86_64
# Date : 04-Oct-2025
# Project Name : gapi2
# License : GPLv3 or later



# Copyright (C) 2026 Amr Alasmer



# g-api is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.

# g-api is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.






cd g-api
source g-api.sh

# set scopes
set_scopes "https://www.googleapis.com/auth/gmail.modify" "https://www.googleapis.com/auth/spreadsheets.readonly"

# first get the access token 
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

