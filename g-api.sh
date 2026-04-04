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


# set -x

# for library use, you must not use any func/var with '__' in the start
__GGL_API_OUT="" # for functions output, to not use subshell every time
__GGL_PID_KILL="" # for php server pid
__GGL_SCOPES_STR="" # for scopes
__GGL_TMP_DIR="" # for tmp dir too store tmp php file
declare -A __GGL_CLIENT_SECRET_DATA=() # to process client secret file once

# for user use, stores output from public functions that meant to be used by user 
GGL_OUTPUT=""

# not for user use, to set it, use set_scopes function
# CHANGE it to make suitable for your program requests 'by set_scopes fucntion'
__GGL_SCOPES_LST=(
    "https://www.googleapis.com/auth/gmail.modify"
    "https://www.googleapis.com/auth/spreadsheets.readonly" 
    "https://www.googleapis.com/auth/drive.file"
)


__set_scopes_str(){
    local i len 
    len="${#__GGL_SCOPES_LST[@]}"

    __GGL_SCOPES_STR="${__GGL_SCOPES_LST[0]}"
    for ((i=1;i<len;i++));do 
        __GGL_SCOPES_STR="${__GGL_SCOPES_STR}+${__GGL_SCOPES_LST[$i]}"
    done 
     
}

__set_scopes_str



set_scopes(){
    local i  

    __GGL_SCOPES_LST=()
    for i in "$@"  ;do 
        __GGL_SCOPES_LST+=( "$i" )
    done 
    __set_scopes_str
}


parse_client_secret_file(){
    if [[ "${#__GGL_CLIENT_SECRET_DATA[@]}" -ne 0 ]]; then 
        return 0
    fi
	local i client_secret_file oldpwd


	if [[ -n "$1" ]]; then  
		oldpwd="$PWD"
		cd "$1" || return 99
		
	fi 
	for i in * ; do 
		if [[ "$i" =~ ^client_secret_.*googleusercontent\.com\.json ]] ; then 
			client_secret_file="${PWD}/${i}"
			break
		fi
	done
	[[ -z "$client_secret_file" ]] && return 99
    parse < "$client_secret_file"
    local key value
    for key in "${!JSON_OUTPUT[@]}"; do
        __GGL_CLIENT_SECRET_DATA["$key"]="${JSON_OUTPUT["$key"]}"
    done
}


check_deps(){
    local i 
    local -a comm
    for i in "$@"; do 
        command -v "$i" &>/dev/null || comm+=( "$i" )
    done
    if [[ "${#comm[@]}" -gt 0 ]]; then
        echo  "the following dependicies are missing:"
        for i in "${comm[@]}" ; do 
            echo -n "${i} , "
        done
        echo "."
    fi
}

check_deps env rm curl dirname mktemp || exit $?

source "`/usr/bin/env dirname ${0}`/json-parser-hm.sh"

# tmp file for use of gurl function
__GGL_GURL_TMPFILE=`/usr/bin/env mktemp`

mktempfifo(){
    __GGL_API_OUT=""
    check_deps  mkfifo  || return $?
    local tmpfifo="`/usr/bin/env mktemp -u`"
    /usr/bin/env mkfifo "$tmpfifo" && __GGL_API_OUT="$tmpfifo"
}


start_local_server(){
    check_deps  cat php sleep ps
    __GGL_API_OUT=""
    local tmpdir="`/usr/bin/env mktemp -d`"
    __GGL_TMP_DIR="${tmpdir}"
    local tmpphp="${tmpdir}/index.php"
    local success=0
    /usr/bin/env cat <<'EOF' > "${tmpphp}"
        
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>vv</title>
    </head>
    <body>
        <?php
            /*
            *
            *	Author : amr
            *                
            *	OS : Debian 13 x86_64
            *
            *	Date : 03-Oct-2025
            *
            *   Project Name : vv
            * 
            */


            $code=$_GET["code"];
            echo "code: " . $code . "<br>";
            $tmpfifo=$_GET["tmpfifo"];
            if (strlen($tmpfifo) > 0){
                echo "fifo file: " . $tmpfifo . "<br>";
                $fifofd = fopen($tmpfifo, "w") or die("Unable to open file!");
                echo "fifo file opened with write perms<br>";
                
                fwrite($fifofd, $code);
                fclose($fifofd);
        
                echo "the write is completed successfully<br>";
                    
            } else {
                echo "Hello to Amr's page!<br>";
            }


        ?>
    </body>
</html>
EOF
    local port i
    for ((i=0;i<15;i++)); do 
        pick_random_port || break
        port="$__GGL_API_OUT"
        /usr/bin/env php -S localhost:$port -t "$tmpdir" &
        __GGL_PID_KILL=$!
        /usr/bin/env sleep .5 
        if /usr/bin/env ps $__GGL_PID_KILL &>/dev/null ; then 
            success=1
            break
        else 
            kill -15 $__GGL_PID_KILL
        fi
    done
    [[ $success -eq 0 ]] &&  { echo "cannot establish server localhost:$port" ; exit 97;  }
    return 0


}


pick_random_port(){
    __GGL_API_OUT=""
    local random i start end
    start=45000
    end=59000 
    for ((i=0;i<100;i++)) ; do 
        random=$RANDOM
        if ((random < start || random > end)); then
            ((random=random*13%end))
            if ((random >= start && random <= end)); then 
                __GGL_API_OUT=$random
                return 0    
            fi 
        else 
            __GGL_API_OUT=$random
            return 0    
        fi 
    done 
    __GGL_API_OUT=$random
}


destroy_token(){
    /usr/bin/env rm token.json 2>/dev/null || true
    /usr/bin/env rm access.json 2>/dev/null || true
}


check_scopes(){
    
    if [[ -z "$1" ]]; then 
        return 93
    fi
    local token_scopes=() 
    local oldifs="$IFS"
    IFS=' ' read -a token_scopes <<< "$1"
    IFS="$oldifs"
    local token_scopes_len="${#token_scopes[@]}"
    local configured_scopes_len="${#__GGL_SCOPES_LST[@]}"
    if [[  $token_scopes_len -ne $configured_scopes_len ]]; then 
        return 92
    fi
    
    local i n matches
    matches=0
    for((i=0;i<token_scopes_len;i++)); do 

        for((n=0;n<configured_scopes_len;n++)); do
            if [[ "${token_scopes[$i]}" == "${__GGL_SCOPES_LST[$n]}" ]] ; then 
                ((matches++))
                break
            fi            
        done
    
    done 
    if [[  $token_scopes_len -ne $matches ]]; then 
        return 91
    fi
    
}
 

get_token(){
    # set +x
    parse_client_secret_file || return $?
    # set -x


    # get these data from the parsed output from client secret json file
    local client_id="${__GGL_CLIENT_SECRET_DATA[".installed.client_id"]}" 
    local client_secret="${__GGL_CLIENT_SECRET_DATA[".installed.client_secret"]}" 
    local auth_uri="${__GGL_CLIENT_SECRET_DATA[".installed.auth_uri"]}"

    local port fifo code


    # PHASE 1

    # make a fifo file to get auth code
    mktempfifo
    # __FIFO="$__GGL_API_OUT"
    fifo="$__GGL_API_OUT"


    # start local http server to receive token 
    start_local_server
    port="$__GGL_API_OUT"

    redirect_uri="http://localhost:$port?tmpfifo=${fifo}"
    echo "*****************************************************************"
    echo ""
    echo "OPEN this URL in your browser, and accept the terms to gain access:"
    echo "https://accounts.google.com/o/oauth2/v2/auth?client_id=$client_id&redirect_uri=$redirect_uri&response_type=code&scope=$__GGL_SCOPES_STR&access_type=offline"
    echo ""
    echo "*****************************************************************"

    check_deps cat
    # TODO: replace it with bash read
    code="`/usr/bin/env cat "$fifo"`"
    kill -15 $__GGL_PID_KILL
    /usr/bin/env rm -r $fifo $__GGL_TMP_DIR



    /usr/bin/env curl -X POST \
    --data "code=${code}&client_id=${client_id}&client_secret=${client_secret}&redirect_uri=${redirect_uri}&grant_type=authorization_code"  \
    https://accounts.google.com/o/oauth2/token \
    -o token.json  &>/dev/null || return 96

}


refresh_access_token(){

    __GGL_API_OUT=""
    # set +x
    parse_client_secret_file || return $?
    # set -x


    # get these data from the parsed output from client secret json file
    local client_id="${__GGL_CLIENT_SECRET_DATA[".installed.client_id"]}" 
    local client_secret="${__GGL_CLIENT_SECRET_DATA[".installed.client_secret"]}" 
    local auth_uri="${__GGL_CLIENT_SECRET_DATA[".installed.auth_uri"]}"


    # if there is token, we will refresh the access token
	if [[ -f "token.json" ]] ;then 
        
        
        # set +x
        parse   < "token.json"
        # set -x
    
        # get the refresh token from the file
        local refresh_token="${JSON_OUTPUT[".refresh_token"]}"

        # send request to refresh the token
        /usr/bin/env curl -X POST \
        --data "client_id=${client_id}&client_secret=${client_secret}&refresh_token=${refresh_token}&grant_type=refresh_token"   \
        https://oauth2.googleapis.com/token -o access.json &>/dev/null 
    
        local stat=$?

        # set +x
        parse  < "access.json"
        # set -x
        
        # if the refreshing did not work, we will try to get new refresh token by showing consent screen
        # maybe there is a way to renew the refresh token without showing the consent screen again, but 
        # I don't know it
        # if ((stat != 0 || "${#JSON_OUTPUT[.access_token]}" == 0 ));then 
        if (("${#JSON_OUTPUT[.access_token]}" == 0 ));then 
            destroy_token || return $? 
            get_token || return $?
            # set +x
            parse   < "token.json"
            # set -x
            __GGL_API_OUT="${JSON_OUTPUT[".access_token"]}"

        else 
            __GGL_API_OUT="${JSON_OUTPUT[".access_token"]}"
        fi    




	else 
        destroy_token # to remove access.json if it was there 
        get_token  || return $?
                
        # set +x
        parse   < "token.json"
        # set -x
        __GGL_API_OUT="${JSON_OUTPUT[".access_token"]}"

    fi


}


get_access_token(){
    OUTPUT=""
    local access_token=""

	if [[ -f "access.json" ]] ;then 
        
        # set +x
        parse   < "access.json"
        # set -x
        
    elif [[ -f "token.json" ]]; then 
        
        # set +x
        parse   < "token.json"
        # set -x
        
    else 
        get_token || return $?

        # set +x
        parse   < "token.json"
        # set -x
                
    fi

    access_token="${JSON_OUTPUT[".access_token"]}"

    if [[ "${#access_token}" -eq 0 ]]; then 
        destroy_token
        return 91
    fi  




    check_scopes "${JSON_OUTPUT[".scope"]}"
    local stat=$?

    if [[ $stat -eq 93 ]]  ; then
        echo "parsing token.json error"
        return $stat
    elif [[ $stat -ne 0 ]]; then 
        destroy_token
        get_token || return $?

        access_token="${JSON_OUTPUT[".access_token"]}"

        # set +x
        parse   < "token.json"
        # set -x


    fi

    local tmpfile=`/usr/bin/env mktemp`
    /usr/bin/env curl "https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=${access_token}" -o "$tmpfile" &>/dev/null  || return 90 

    # set +x    
    parse  < "$tmpfile" 
    # set -x

    /usr/bin/env rm "$tmpfile" &>/dev/null
    # echo "${JSON_OUTPUT[".expires_in"]}"
    # echo "${JSON_OUTPUT[".scope"]}"
    # echo "${JSON_OUTPUT[".exp"]}"
    if [[ -z "${JSON_OUTPUT[".expires_in"]}" ]]; then  
        refresh_access_token || return $? 
        access_token="$__GGL_API_OUT"
    fi

    OUTPUT="$access_token"


}


# wrapper for curl, use it for api requests, it checks for errors if the token expired, etc...
gurl(){
    /usr/bin/env curl "$@" 2>/dev/null >"$__GGL_GURL_TMPFILE" || return 89
    parse < "$__GGL_GURL_TMPFILE"
    if [[ "${#JSON_OUTPUT[.error.code]}" -gt 0 ]]; then 
        /usr/bin/env cat "$__GGL_GURL_TMPFILE" 2>/dev/null
        echo "" >"$__GGL_GURL_TMPFILE"
        return 88
    else
        echo "" >"$__GGL_GURL_TMPFILE"
        return 0
    fi
}


# for future, these wrappers will be easy to implement, only it needs to study the APIs 
# send_email(){}
# create_draft(){}
# read_sheet_range(){}
# 


example(){
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

}

# this example will create a new draft message "tst email" 
example

