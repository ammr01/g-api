#!/usr/bin/env bash
# Author : amr
# OS : Debian 13 x86_64
# Date : 18-Mar-2026
# Project Name : json-parser
# License : GPLV3 or later

# Original Code by: https://github.com/fkalis/  
# Original Code: https://github.com/fkalis/bash-json-parser
# I enhanced original code by:  
# * add querying capabilities like jq
# * made it x2 faster
# * add input/output buffering
# * add caching to not process same input multiple times, only processing it one time 
# * add error checking 



# I did not fork it or add pull request because of 
# licensing, original project use MIT license, but I used GPLv3 or later licence.


# TODO List:
# hashmap for uncompleted arrays/object identification [not now, in the future]
# check for uncompleted values if the line ends in read new line [not now, in the future]





# Copyright (C) 2026 Amr Alasmer


# json-parser is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.

# json-parser is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.



# scopes
readonly __ROOT=1
readonly __VAR_NAME=2
readonly __ENTRY_SEPARATOR=3
readonly __STRING=4
readonly __NUMBER=5
readonly __BOOLEAN=6
readonly __FIELD_SEPARATOR=7
readonly __KEY_VALUE_SEPARATOR=8



function __clear_values() {
    # clear these values every time parse function is called
	# __out_buf=""
	__chars_read=0
	__in_buf=""
	__EOF=0
	# __out_buf_size=4000	
	__LINE_ID=0
	__FILTER=""
	__regex=""
    declare -gA JSON_OUTPUT=()

}




function __clear_errors() {

	# for error handling, 1=true , 0=false
	# __COMPLETED_VALUE=1
	# __COMPLETED_NAME=1
	# __COMPLETED_OBJECT=1
	# __COMPLETED_ARRAY=1
	# __COMPLETED_JSON=0
	__UNEXPECTED_VALUE=0
	__UNEXPECTED_CHAR=0
	# __ESCAPING_ERROR=0
	# declare -A __UNCOMPLETED_ARRAYS_LIST=()
	# declare -A __UNCOMPLETED_OBJECTS_LIST=()

	__UNCOMPLETED_OBJECTS_COUNT=0
	__UNCOMPLETED_ARRAYS_COUNT=0
	__UNCOMPLETED_OBJECT=0
	__UNCOMPLETED_ARRAYS=0
	# __CORRUPTED_CACHE=0
	__ERRORS_LOCATION=()

}


function clear_cache() {
    declare -gA __cache=()
	__clear_errors
}

function enable_cache() {
	__cache_enabled=1
}



function disable_cache() {
	__cache_enabled=0
}


__clear_values
clear_cache

# by default caching is not enabled, to enable it use `enable_cache` function
disable_cache




# this function will build a posix extended regular expression from the filter
# to get the filter syntax go to json-parser.md file
function __build_filter_regex() {
	__regex="^"
	local x c state filter_len escaped array_wildcard  next_char
	filter_len="${#__FILTER}"
	state=$__ROOT
	escaped=0
	array_wildcard=0
	if [[ -n "$__FILTER" ]]; then
		for ((x=0;x<filter_len;)); do 
			c="${__FILTER:$x:1}"
			case "$state" in
				$__ROOT) 

					case "$c" in
						'.') 
							__regex="${__regex}\\."
							((x++))
							;;
						*) 
							state=$__STRING
							;;
					esac

					;;
				$__STRING) 
					case "$c" in
						'\')
                            array_wildcard=0
							((x++)) 
							[[ $escaped -eq 1 ]] && __regex="${__regex}\\"
							((escaped=1-escaped))
							;;
						'*') 
                            array_wildcard=0
							((x++))
							case "$escaped" in
								0)
                                    next_char="${__FILTER:$x:1}"
                                    if [[ "${next_char}" == '*' ]]; then 
                                        __regex="${__regex}.*"
                                        ((x++))
                                    else 
                                        __regex="${__regex}[^\\.]*"
                                    fi 
									;;
								1)
									__regex="${__regex}\\*"
                                    escaped=0
									;;

							esac
							;;

						'[')
							((x++)) 
                            __regex="${__regex}\\${c}"
                            array_wildcard=1
                            escaped=0

							
							
							;;
						'.') 
                            array_wildcard=0
                            escaped=0
                            # __regex="${__regex}\\${c}"
                            state=$__ROOT
                            ;;

							
						']') 
							((x++))
                            escaped=0
                            case "$array_wildcard" in
                                0)											
                                    __regex="${__regex}\\${c}"
                                    ;;
                                1)
                                    __regex="${__regex}[0-9]+\\${c}"
                                    array_wildcard=0
                                    ;;
                            esac
                            ;;
							

						[\`\$\']) 
                            array_wildcard=0
							((x++)) 
							__regex="${__regex}\\${c}"

                            ;;
						[[:blank:]]) 
                            array_wildcard=0
							((x++)) 
							__regex="${__regex}[[:blank:]]"

                            ;;
							
						*) 
                            array_wildcard=0
                            escaped=0
							((x++))
							__regex="${__regex}${c}"
							;;
					esac


                    ;;
			esac
		done	
		__regex="${__regex}\$"
		# echo "${__regex}"
	else
		return
	fi
}


# add key value pair to output buffer
# function __add_out_buf() {
# 	__out_buf="${__out_buf}${1}=${2}
# "
# }


function __add_out_buf() {
	JSON_OUTPUT["$1"]="$2"
}



# add key and value into the cache if the cache is enabled
function __add_to_cache() {
	if [[ $__cache_enabled -eq 1 ]]; then
        local path="$1" 
        __cache["$path"]="$2"
	fi 
}





# handle parsed key-value pair, add it to cache "if enabled", and check if the filter applies 
function __output_entry() {
	local path="$1"
	local value="$2"

    # in the future, i will add some optimizations here maybe, to stop checking if the filter applies,
    # if we are sure there will be no key matches the filter after the current key, for example arrays:
    # if the filter is .[0]**, so after the first element, we must stop matching. 

    # will be added if cache enabled only
	__add_to_cache "$path" "$value"
	if [[ -n "$__FILTER" ]]; then 
        # check if the filter applies on that key-value pair, if yes add it to output buf
        # FIXED Remote Code Execution vuln using single quotes for path and value
		eval "[[ '$path' =~ $__regex ]] && __add_out_buf '$path' '$value' "
	else 
        # if no filter is specified then add all key-value pair to output buffer
		__add_out_buf "$path" "$value"
	fi 

}




# read new line from stdin
function __read_new_line() {
    # only read new line if we processed the whole inbut buffer, if not processed then do nothing
    # in the future i will add checks if we finished the current buffer, but still have value not finished
    # of key name not finished, must raise a error
	if [[ $__JSN_GLB_ITR -ge $__in_buf_len ]]; then  
		__JSN_GLB_ITR=0
		local OLDIFS="${IFS}"
		IFS=$'\n' read -r -s __in_buf 
		local stat=$?
		IFS="${OLDIFS}"
		__in_buf_len=${#__in_buf}
		((__chars_read=__chars_read+__in_buf_len+1,__LINE_ID++))
		[[ $stat -eq 0 ]] || { __EOF=1; ((__chars_read=__chars_read-1)) ; return $stat ; }	
	fi
}


function validate_num() {
	local regex="^[\-\+]?[0-9]+(\.[0-9]+)?$|^[\-\+]?([0-9]+)?\.[0-9]+$"
	local num="$1"
	local location="$2"
	if ! [[ "$num" =~ $regex ]] ; then 
		__UNEXPECTED_VALUE=1
		# this way to calculate the  
		# local varloc=$((location-${#num}))
		# __ERRORS_LOCATION+=( "Unexpected value at : ${__LINE_ID}:${location}" )
		__ERRORS_LOCATION+=( "Unexpected value at : ${location}" )
	fi

}


function validate_bool() {
	local regex="^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$"
	local bool="$1"
	local location="$2"
	if ! [[ "$bool" =~ $regex ]] ; then 
		__UNEXPECTED_VALUE=1
		__ERRORS_LOCATION+=( "Unexpected value at : ${location}" )
	fi

}



function parse_value() {
	local current_path="${1:+$1.}$2"
	local current_scope=$__ROOT
	local c current_varvalue current_escaping location

	local break=0

	while true   ; do

		if [[ $break -ne 0 ]]; then 
			break
		fi
		if [[ $__EOF -ne 0 ]]; then 
			break=1
		fi
		__read_new_line 

		for ((;__JSN_GLB_ITR<__in_buf_len;))   ; do
			c=${__in_buf:$__JSN_GLB_ITR:1}
			case "$current_scope" in
				$__ROOT) # Waiting for new string, number or boolean
					((__JSN_GLB_ITR++))
					case "$c" in
						'"') # String begin
							current_scope=$__STRING
							current_varvalue=""
							;;
						[\-\+0-9\.]) # Number begin
							current_scope=$__NUMBER
							current_varvalue="$c"
							;;
						"[") # Array begin
							parse_array "" "$current_path" 
							return
							;;
						"{") # Object begin
							parse_object "" "$current_path"
							return
							;;
						[[:space:]])
							;;
						*) # other "mostly boolean"
							current_scope=$__BOOLEAN
							current_varvalue="$c"
							;;
						
					esac
					;;
				$__STRING) # Waiting for string end
					((__JSN_GLB_ITR++))
					case "$c" in
						'"') # String end if not in escape mode, normal character otherwise
							case "$current_escaping" in
								0)
									__output_entry ".$current_path" "$current_varvalue"  
									return
									;;
								1)
									current_varvalue="${current_varvalue}${c}"  
									current_escaping=0
									;;
							esac
							;;
						'\') # Escape character, entering or leaving escape mode
							[[ "$current_escaping" == "1" ]] && current_varvalue="${current_varvalue}${c}"
							((current_escaping=1-current_escaping))
							;;
						*) # Any other string character
							current_escaping=0
							current_varvalue="${current_varvalue}${c}"
							;;
					esac
					;;
				$__NUMBER) # Waiting for number end
					case "$c" in
						[,\]}]) # Separator or array end or object end
							validate_num "$current_varvalue" "$location" 
							__output_entry ".$current_path" "$current_varvalue"
							return
							;;
						[\-\+0-9\.]) # Number can only contain digits, dots and a sign
							[[ -z "${location}" ]] && location="${__LINE_ID}:${__JSN_GLB_ITR}"
							((__JSN_GLB_ITR++))
							current_varvalue="${current_varvalue}${c}"
							;;
						[[:space:]])
							((__JSN_GLB_ITR++))
							;;
						*)
							__UNEXPECTED_CHAR=1
							__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
							((__JSN_GLB_ITR++))
							;;
					esac
					;;
				$__BOOLEAN) # Waiting for boolean to end
					case "$c" in
						[,\]}]) # Separator or array end or object end
							validate_bool "$current_varvalue" "$location" 
							__output_entry ".$current_path" "$current_varvalue"
							return
							;;
						*) 
							[[ -z "${location}" ]] && location="${__LINE_ID}:${__JSN_GLB_ITR}"
							((__JSN_GLB_ITR++))
							current_varvalue="${current_varvalue}${c}"
							;;
					esac
					;;
			esac
		done
	done
}



function parse_array() {
	local current_path="${1:+$1.}$2"
	local current_scope=$__ROOT
	local current_index=0
	local c
	local caller_func="${FUNCNAME[1]}"
	local break=0

	((__UNCOMPLETED_ARRAYS_COUNT++))


	while true   ; do

		if [[ $break -ne 0 ]]; then 
			break
		fi
		if [[ $__EOF -ne 0 ]]; then 
			break=1
		fi

		__read_new_line  
		for ((;__JSN_GLB_ITR<__in_buf_len;))   ; do
			c=${__in_buf:$__JSN_GLB_ITR:1}


			case "$current_scope" in
				$__ROOT) # Waiting for new object or value
					case "$c" in
						'{')
							((__JSN_GLB_ITR++))
							parse_object "$current_path" "[$current_index]"
							current_scope=$__ENTRY_SEPARATOR
							;;
						']')
							((__JSN_GLB_ITR++))
							((__UNCOMPLETED_ARRAYS_COUNT--))
							return
							;;
						[\"a-zA-Z\-\+\.0-9])
							parse_value "$current_path" "[$current_index]"
							current_scope=$__ENTRY_SEPARATOR
							;;
						[[:space:]])
							((__JSN_GLB_ITR++))
							;;
						*)
							((__JSN_GLB_ITR++))
							__UNEXPECTED_CHAR=1
							__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
							;;
							
						# TODO: check for other cases
					esac
					;;
				$__ENTRY_SEPARATOR)
					case "$c" in
						',')
							((__JSN_GLB_ITR++))
							((current_index=current_index+1)) 
							current_scope=$__ROOT
							;;
						']')
							((__JSN_GLB_ITR++))
							((__UNCOMPLETED_ARRAYS_COUNT--))
							return
							;;
						'}')
							if [[ "$caller_func" == "parse_object" ]] ;then 
								return
							else
								((__JSN_GLB_ITR++))
								__UNEXPECTED_CHAR=1
								__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
							fi
							;;
						[[:space:]])
							((__JSN_GLB_ITR++))

							;;
						*)
							((__JSN_GLB_ITR++))
							__UNEXPECTED_CHAR=1
							__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
							;;
					esac
					;;
			esac
		done
	done
}



function parse_object() {
	local current_path="${1:+$1.}$2"
	local current_scope=$__ROOT
	local c current_varname current_escaping
	local break=0
	local caller_func="${FUNCNAME[1]}"
	((__UNCOMPLETED_OBJECTS_COUNT++))

	while true   ; do

		if [[ $break -ne 0 ]]; then 
			break
		fi
		if [[ $__EOF -ne 0 ]]; then 
			break=1
		fi

		__read_new_line 
		for ((;__JSN_GLB_ITR<__in_buf_len;))   ; do
			c=${__in_buf:$__JSN_GLB_ITR:1}

			case "$current_scope" in
				$__ROOT) # Waiting for new field or object end

					case "$c" in
					"}") 
						((__JSN_GLB_ITR++))
						((__UNCOMPLETED_OBJECTS_COUNT--))
						return  
						;;
					'"')
						current_scope=$__VAR_NAME  
						current_varname=""  
						current_escaping=0
						;;
					[[:space:]])
						;;


					*)
						__UNEXPECTED_CHAR=1
						__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
						;;
					esac
					((__JSN_GLB_ITR++))

					;;
				$__VAR_NAME) # Reading the field name
					case "$c" in
						'"') # String end if not in escape mode, normal character otherwise
							if [[ "$current_escaping" == "0" ]]; then 
								current_scope=$__KEY_VALUE_SEPARATOR
							elif [[ "$current_escaping" == "1" ]] ;then 
								current_varname="${current_varname}${c}" 
								current_escaping=0
							fi
							;;
						'\') # Escape character, entering or leaving escape mode
							((current_escaping=1-current_escaping))
							current_varname="${current_varname}${c}"
							;;
						=) # escape the equals sign because of output formatting
							if [[ $current_escaping -eq 0 ]]; then
								current_varname="${current_varname}\\${c}" 
							elif [[ $current_escaping -eq 1 ]] ;then 
								current_varname="${current_varname}${c}"
								current_escaping=0
							fi

							;;
						[\']) # escape the single qoute
							if [[ $current_escaping -eq 0 ]]; then
								current_varname="${current_varname}'\\${c}'" 
							elif [[ $current_escaping -eq 1 ]] ;then 
								current_varname="${current_varname}'\\${c}'"
								current_escaping=0
							fi

							;;
						*) # Any other string character
							current_escaping=0
							current_varname="${current_varname}${c}"
							;;
					esac
					((__JSN_GLB_ITR++))
					;;
				$__KEY_VALUE_SEPARATOR) # Waiting for the key value separator (:)
					((__JSN_GLB_ITR++))  
					case "$c" in

						':')  
							parse_value "$current_path" "$current_varname" 
							current_scope=$__FIELD_SEPARATOR 
							;;
						[[:space:]])
							;;
						*)
							__UNEXPECTED_CHAR=1
							__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
							;;
					esac
	
					;;
				$__FIELD_SEPARATOR) # Waiting for the field separator (,)
					case "$c" in
						',')
							current_scope=$__ROOT
							;;
						'}')
							((__UNCOMPLETED_OBJECTS_COUNT--))
							((__JSN_GLB_ITR++))  
							return
							;;
						']')
							if [[ "$caller_func" == "parse_array" ]] ;then 
								# ((__UNCOMPLETED_ARRAYS_COUNT--))
								# ((__JSN_GLB_ITR++))  
								return
							else
								__UNEXPECTED_CHAR=1
								__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
							fi
							;;
						[[:space:]])
							;;
						*)
							__UNEXPECTED_CHAR=1
							__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
							;;										
					esac
					
					((__JSN_GLB_ITR++))
					;;
			esac
		done
	done
}


function tell_errors() {

	local e
	for e in "${__ERRORS_LOCATION[@]}"; do 
		echo "$e" 1>&2
	done
	
}



function parse() {

	local c
	__clear_values
	__FILTER="$1"
	[[ -n "$__FILTER" ]] &&	__build_filter_regex


	if [[ $__cache_enabled -eq 1 ]]; then
		
		local clen=${#__cache[@]}

		local x name value
        for name in "${!__cache[@]}"; do 
			value="${__cache[$name]}"
			if [[ -n "$__FILTER" ]]; then 
				# could be used in RCE , but fixed using ' 
				eval "[[ '$name' =~ $__regex ]] && __add_out_buf '$name' '$value' "
			else 
				__add_out_buf "$name" "$value"
			fi
		done 
		

		
		if (( clen != 0 )); then 
			tell_errors
			return
		fi
	fi

	
	while [[ $__EOF -eq 0 ]]   ; do

		__read_new_line 

		for ((;__JSN_GLB_ITR<__in_buf_len;))   ; do
			c=${__in_buf:$__JSN_GLB_ITR:1}
			((__JSN_GLB_ITR++))

			case "$c" in
				"{") 
					# A valid JSON string consists of exactly one object
					# ((__UNCOMPLETED_OBJECTS_COUNT++))
					# __COMPLETED_OBJECT=0
					parse_object  
					# return  
					;;
				"[")
					# ... or one array
					# __COMPLETED_ARRAY=0
					# ((__UNCOMPLETED_ARRAYS_COUNT++))
					parse_array 
					# return 
					;;
				[[:space:]])
					;;
				*)
					__UNEXPECTED_CHAR=1
					__ERRORS_LOCATION+=( "Unexpected char at : ${__LINE_ID}:${__JSN_GLB_ITR}" )
					;;										
			esac
		done 
	done

	if [[ $__UNCOMPLETED_OBJECTS_COUNT -ge 1 ]]; then
		__UNCOMPLETED_OBJECT=1
		__ERRORS_LOCATION+=( "Uncompleted objects detected" )
	fi

	if [[ $__UNCOMPLETED_ARRAYS_COUNT -ge 1 ]]; then
		__UNCOMPLETED_ARRAYS=1
		__ERRORS_LOCATION+=( "Uncompleted arrays detected" )		
	fi 

	tell_errors
}







