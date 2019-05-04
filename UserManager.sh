#! /bin/bash
#
#> V1    - only had basic funtionality, would give you commands to run.
#>===
#> V1.2  - added more options, also prompted you and auto-ran.
#>===
#> V1.3  - fixed remaining bugs and updated case statments - added disabling users
#>===
#> V1.4  - added version check in.
#>===
#> V2    - added groups & reporting - fully restructured to using copied scripts
#>         via sed, instead of one liners. Added colors as well.
#>===
#> V2.1  - added more colors, made it more robust with traps to make sure it cleans
#>         up properly in the event of a sigint.
#>===
#> V2.2  - fixed the user report to include sudoers.d.
#>       - fixed the sudo permissions to make sure a '.' is not included in the file 
#>         name, as it apparently is otherwise unable to read them.
#>===
#> V2.3  - Added clean error handling for all of the scripts, and traps for sigints
#>         so that stray files are not left behind.
#>       - set output to quiet and added a different header for each device the 
#>         script is run on.
#>       - added checks for sudoers files and existing users so permissions would not get
#>         convoluted
#>===
#> V2.4  - Switched report to pull from local instead of local + domain
#>       - Added last password change to audit report per request
#>       - Started adding flags ( -o, -l & -h)
#>       - Added help information
#>       - Added more checks for users - makes certain a local user doesn't get created on 
#>         top of a domain user
#>===
#> V3    - Added 8 (remove users from groups)
#>       - increased password hash to sha512
#>       - Added multi-user functionality to everything (proved to be rather difficult >.>)
#>       - add checks for inconsistent/unequal variables for multi additions
#>       - did a lot of cleanup and re-ordering
#>       - added lots of comments
#>       - added colors to all errors and sub scripts
#>       - added -d, -v flags/functionality
#>       - revised versions to better reflect small/large changes
#>===
#> V3.1  - fixed httag to check for multiple variables
#>       - fixed ordering of ssh-args for 5 & 8
#>       - fixed color display on first output of 6
#>       - changed array for 7 to support older versions of bash ( :sadface: )
#>       - aesthetic changes (colors/spacing)
#>       - added better information to help - gave prompts for -h
#>       - added sed statement to remove start & end lines
#>=== 
#> V3.2 - added password generator option
#>      - wrapped around most long echo statements
#>===
#> V3.3 - added expirey to user additions so they are forced to change their password
#>      - changed prompt for sudo to run through the list  of users, instead of specifying one at a time
#>      - fixed small typo in error message
#>      - added some more comments to explain the script
#>===
#> V3.4 - fixed echo statements
#>      - Decided to remove --skip-checks from all instead
#>      - added 'sort -u' to #6 in for loops, as it led to duplicate entries in the report
#>      - added a small space to the starting options
#>===
#> V3.5 - set expire of new accounts as an toggleable option, whereas all new accounts were set to auto-expire
#>      - removed a stray line from the help message
#>      - made the audit report customizable
#>===
#> V3.6 - added to if statement to include another option for the audit, couldn't do yyny before
#>      - added an entry to pull the most recent changes when checking version
#>      - added a changelog
#>===
#> V3.7 - adjusted some output formatting
#>      - parsed through groups for users similar to with sudoers
#>      - added a summary for each run, pass/fail devices. Rolled 3.6.1 into 3.7
#>===
#
#
# To do:
# [+] Allow single quotes for passwords, right now it's the only character that will break the perl statement
# [+] Mysql User compatibility
# [+] sftp user compatibility
# [+] unset arrays before they're use/check if they're being used
# [+] simplify if/for loop statements to put if;then and for;do on one line
# [+] tbh a lot of things coulkd be simplfied now with better functions
#
## Colors
D_RD='\e[38;5;88m'
L_GRN='\e[38;5;41m'
S_BLUE='\e[38;5;45m'
L_GRY='\e[38;5;244m'
WHTE='\e[38;5;231m'
CLR='\e[0m'

## Script version
version=$(grep '#> V[0-9]' ${0} | awk 'END{print $2}') 
scriptversion="$0 -- Version: ${version}"
rawversion=$(echo ${version} | cut -d'V' -f2)
## trap to cleanup any temporary files if this gets interrupted
cleanuptmp(){
    echo -e "\n ${D_RD}[ STOPPED ]${CLR} ${WHTE}Recieved SIGINT - Cleaning up.${CLR} "
    rm -f -- ${TMPSCRIPT} ${TMPRSLTS}
    exit 2
}
trap cleanuptmp SIGINT

###
## Check that they have pssh (just to be certain), exit if they don't
###

if [[ ! $(which pssh 2> /dev/null) ]]
then
    echo "pssh not found, please install it and ensure it is listed in your \$PATH."
    exit 1
else
    :
fi

###
## List of all the script options we call a few times, this just makes the script a little more 
## readable later on
###

listallnumbers="    ${L_GRN}[1]${CLR} ${S_BLUE}Create a User(s)${CLR}
    ${L_GRN}[2]${CLR} ${S_BLUE}Change a User(s) Password${CLR}
    ${L_GRN}[3]${CLR} ${S_BLUE}Give user(s) Sudo Permissions${CLR}
    ${L_GRN}[4]${CLR} ${S_BLUE}Create a user(s) with Sudo Perms${CLR}
    ${L_GRN}[5]${CLR} ${S_BLUE}Add a user(s) to a group${CLR}
    ${L_GRN}[6]${CLR} ${S_BLUE}Return a list of active users/groups/sudoers${CLR}
    ${L_GRN}[7]${CLR} ${S_BLUE}Disable a User(s)${CLR}
    ${L_GRN}[8]${CLR} ${S_BLUE}Remove a User(s) from a group${CLR}"
###
## These are where all the options are for running it based off flags, essentially, if no argument is given
## it run in interpretive mode, and awaits a response. If a flag is given, it checks it through a case statement
###

if [[ -z $1 ]]
then
    echo -en "${WHTE}What would you like to do?${CLR}
             
${listallnumbers}
${WHTE}Please respond with a number [1-8]:${CLR} "
    read VARPATH
    echo
    echo -e "${WHTE}==================${CLR}"
    ## Check to make sure correct arguments were passed, if not, leave a message and exit
   if [[ "$VARPATH" =~ [1-8] ]]
    then
        :
    else
        echo "Invalid Entry. Please try again, or see -h | --help | help"
        exit 1
    fi
else
    # This is a check to make sure no more than the required variables are passed
    variablescheck(){
    if [[ ${@} -gt 1 ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- There can only be 1 variable passed with this option. "
        exit 1
    else
        :
    fi
    }    
    # this is the case statement that interprets the first variable they pass to the script
    case ${1} in
        -h | --help | help )
            echo -e "${WHTE}==============================================${CLR}
    This script is to help manage user(s) across a large number of devices. It 
    works just as well with just device if that be the case also. If help beyond 
    this is needed, please read over the documentation here: 
    
    https://github.com/paralllax/UserManager.sh/tree/master

    There are a few ways to run the script. Either call it directly, in which
    case an interactive menu pulls up, you then select an option from the menu.

    # ${WHTE}./user-config.sh${CLR}
${listallnumbers}

    Alertnatively, you can specify with -o or --options followed by one of the 
    above numbers. This will skip the menu.
 
    # ${WHTE}./user-config.sh -o 6${CLR}
    # ${WHTE}./user-config.sh -l${CLR}
    # ${WHTE}./user-config.sh -h${CLR}

    Note that when you are supplying mutliple users, equal numbers of passwords
    and related variables need to be listed. If you are removing 5 users from the 
    same group, the same group needs to be set 5 times, once for each user.
${WHTE}==============================================${CLR}

        -c | --change-log  -- shows all historical changes to the script

        -d | --download    -- gives the download link for the script
        
        --help | -h | help -- See this message

        -l | --list        -- Lists the different numbers for --options as shown
                              above. 
        
        -o | --options     -- Specify a number 1-7 to skip the menu and proceeed
                              with one of the above set tasks.     

                              Ex: The following will proceed with 6, user audit
                              #./user-config.sh -o 6

        -v | --version     -- shows the script version"
        
            exit 0
            ;;

        -o | --options )
            # all this does is check that $2 is a valid number, then set's it as the varpath for another case
            # statement we have down below, which decides what the script will do 
            if [[ -z $2 ]]
            then
                echo -e "${D_RD}[ FAIL ]${CLR} ${WHTE}Please specify a number [ 1-8 ]${CLR}"
                exit 2
            elif [[ "${2}" =~ [1-8] ]]
            then
                :
            else
                echo -e "${D_RD}[ FAIL ]${CLR} ${WHTE}Please specify a number [ 1-8 ]${CLR}"
                exit 2
            fi
            VARPATH="${2}"
            ;;
        -l | --list )
            variablescheck
            echo -e "${listallnumbers}"
            exit 0
            ;;
         -v | --version )
             variablescheck
             echo $scriptversion | sed 's/\.\///'
             echo
             echo "Recent Changes:"
             awk ' /'"$version"'/ {flag=1} /'">==="'/{flag=0} flag { print }' $0 | sed 's/#>//g'
             exit 0
            ;;
         -c | --change-log )
             echo "[---------] CHANGE LOG [---------]"
             echo
             grep '^#>' $0 | sed 's/#>//g'
             exit 0
             ;;
        * ) 
            echo "Invalid Entry. Please try again, or see -h | --help | help"
            exit 1
            ;;
    esac    
fi

#########
#####
#### These are all of the functions, well most all of them. They are called by a case statement below.
#### The functions here pull all of our variables, as well as do most of the checks to ensure nothign
#### is passed that could break the scripts later on
#####
#########

separatesec(){
# will change separators eventually, currently, just a space for now
echo
#    echo -e "${L_GRN}|--${S_BLUE}${#USRNME[@]}${L_GRN}--|${CLR}"
}


getuserinfo(){
# This function pulls the username for our stuff later, then converts it into an array
    echo -en "Username (If multiple list with space \" \" as the deliminator):"\
             "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: "
    read USRNME
    USRARRAY=($USRNME)
    separatesec 

}

getticketinfo(){
    echo -en "Device IP or Hostname (If multiple list with comma \",\" as the deliminator): "\
             "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: " 
    read TCKT
    separatesec
}

getgroupinfo(){
# gets the group information, then converts it into an array, parses through the user
# to match the group with each
    if [[ "${#USRARRAY[@]}" -gt "1" ]]
    then
        echo "Type the group that the given user will be associated with:"
        for ((i=0; i<${#USRARRAY[@]}; i++)); do
            echo -en "${L_GRN}|--${S_BLUE}${USRARRAY[i]}${CLR}${L_GRN}--|${CLR}: "
            read GRPNME
            GRPARRAY+=(${GRPNME})
        done
        echo
    else
        unset GRPARRAY
        echo -en "Group associated with user:"\
             "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: " 
        read GRPARRAY
        separatesec
    fi
}

getexpireinfo(){
# tells us whether or not we will expire the account when creating new users
# if yes, they are forced to reset their password on login
echo -en "Set the password to expire on first use [y/n]? (forces user to change password on login)"\
             "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: " 
    read EXPIREYN
    case $EXPIREYN in
        [y-Y]* )
            expiretoken="EXPIREACCOUNT"
            ;;
        [n-N]* )
            expiretoken=""
            ;;
        * ) echo "${D_RD}[ FAIL ]${CLR} -- ${WHTE} Response is not accepted. Please try again.${CLR}"
            exit 1
            ;;
    esac
    separatesec
}

getgecosinfo(){
# gets user name for disable script
    echo -en "Username (If multiple list with space \" \" as the deliminator):"\
             "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: "
    read USRNME
    USRARRAY=($USRNME)

# This is a tag we set to make sure the right branch of commands are run in the script we
# copy to the remote server
    if [[ "${#USRARRAY[@]}" -gt "1" ]]
    then
        HTTAG="multiple-on"
    else
        :
    fi

#These are just checks to make sure bad information isn't passed to the script    
    if [[ -z ${USRARRAY[@]} ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Empty response is not accepted. Please try again.${CLR}"
        exit 1
    else
        :
    fi
    separatesec

# gets the comment for the GECOS
    echo -en "GECOS Comment we will add (no spaces):"\
             "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: " 
    read DISTCKT
    DTCKTARRAY=($DISTCKT)
    if [[ -z ${USRARRAY[@]} || -z ${DTCKTARRAY[@]} ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Empty response is not accepted. Please try again.${CLR}"
        exit 1
    elif [[ "${#DTCKTARRAY[@]}" -gt "1" ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Only one response is accepted. Please try again.${CLR}"
        exit 1
    else
        :
    fi
    separatesec
}

getpassinfo(){
# This gets the password, or generates a password for each user
    echo -en "Do you want to auto-generate passwords? [y/n]:"\
             "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: "
    read GENPASS
    case $GENPASS in
        [y-Y]* )
            # essentially, for each user, create a password. It pulls from /dev/urandom, then replaces 
            # all the characters, and prints the first 24m which becomes the password. This is added to 
            # an array
            for ((i=0; i<${#USRARRAY[@]}; i++))
            do
                PASSWRD=$(</dev/urandom tr -dc 'A-Za-z0-9!\#$%&()*+,-./:;<=>?@[\]^_{|}~' | head -c 24)
                PASSARRAY+=($PASSWRD)
                echo -e "${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: Password for ${L_GRN}"\
                        "${USRARRAY[i]}${CLR} is -- ${L_GRN}${PASSARRAY[i]}${CLR} --"
            done
            separatesec
            ;;
        [n-N]* )
        echo
        echo -en "Password (If multiple list with space \" \" as the deliminator):"\
                 "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: " 
        read PASSWRD
        PASSARRAY+=($PASSWRD)
        separatesec
            ;;
        * ) echo "${D_RD}[ FAIL ]${CLR} -- ${WHTE} Response is not accepted. Please try again.${CLR}"
            exit 1 
            ;;
    esac
}

getsudoinfo(){
    if [[ "${#USRARRAY[@]}" -gt "1" ]]
    then
        echo -e "Require Password on (sudo) use for the following users: [y/n]"
        for ((i=0; i<${#USRARRAY[@]}; i++))
        do
            echo -en "${L_GRN}|--${S_BLUE}${USRARRAY[i]}${CLR}${L_GRN}--|${CLR}: "
            read sudoarrayrsp
            SUDOYN+=(${sudoarrayrsp})
        done
        echo
    else
        unset SUDOYN
        echo -en "Require Password on (sudo) use: [y/n]"\
                 "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: " 
        read SUDOYN
        #echo -e "${L_GRN}|--${S_BLUE}${#SUDOYN[@]}${L_GRN}--|${CLR}"   
        separatesec
    fi
}

gethashpass(){
    if [[ ${PASSARRAY[@]} == "*[\']*" ]]
    then
        echo "Sorry, single quotes are the only special character for passwords not supported with this script yet."
        exit 1
    else
        :
    fi
    if [[ "${PASSARRAY[@]}" =~ " " ]]
    then
        OIFS=$IFS
        IFS=" "
        for ((i=0; i<${#PASSARRAY[@]}; i++))
        do
            HASHPASS=$(perl -e "print crypt('${PASSARRAY[i]}', '\$6\$saltsalt\$')"| sed 's/\$/REPLACE-TAG/g')
            HTPASS+=($HASHPASS)
        done
        #HTPASS=( $(printf "\'%s\' " "${HTPREP[@]}") )
        IFS=$OIFS
    else
        HASHPASS=$(perl -e "print crypt('$PASSWRD', '\$6\$saltsalt\$')"| sed 's/\$/REPLACE-TAG/g')
        HTPASS=($HASHPASS)
    fi
}

getsudocase(){
if [[ "${#SUDOYN[@]}" -gt "1" ]]
then
    OIFS=$IFS
    IFS=" "
    for ((i=0; i<${#SUDOYN[@]}; i++))
    do
        case ${SUDOYN[i]} in
            [y-Y]* )
                SDOCMD="ALL"
                ARRSDOCMD+=($SDOCMD)
                ;;
            [n-N]* )
                SDOCMD="NOPASSWD:ALL"
                ARRSDOCMD+=($SDOCMD)
                ;;
                 * ) 
                echo -e "${D_RD}[ ERROR ]${CLR} ${L_GRN}${SUDOYN[i]}${CLR} ${WHTE}not valid response."\
                        "Please try again.${CLR}"
                exit 1
                ;;
        esac
    done
else
    case $SUDOYN in
        [y-Y]* )
            ARRSDOCMD="ALL"
            ;;
        [n-N]* )
            ARRSDOCMD="NOPASSWD:ALL"
            ;;
             * )
            echo -e "${D_RD}[ ERROR ]${CLR} ${L_GRN}${SUDOYN}${CLR} ${WHTE}not valid response."\
                    "Please try again.${CLR}"
            exit 1
           ;;
  esac
fi
}

startrun(){
    sed -i '/^### START.*/d' ${TMPSCRIPT}
    sed -i '/^### END.*/d' ${TMPSCRIPT}
    echo
    echo -e "${S_BLUE}Depending on the number of devices, this may take sometime. Please be patient.${CLR}"
    echo
    echo -e "${S_BLUE}Running against${CLR} ${L_GRN}${TCKT}...${CLR}"
    echo
}

finishrun(){
    rm -f -- ${TMPSCRIPT}
    exit 0
}


userpasscheck(){
    OIFS=$IFS
    IFS=' '
    if [[ "${#USRARRAY[@]}" != "${#HTPASS[@]}"  ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}There are ${#USRARRAY[@]} users and ${#HTPASS[@]} passwords.${CLR}"
        echo -e "             ${WHTE}These should be equal. Please try again, or see -h | --help | help${CLR}"
        exit 1
    else
        if [[ "${#USRARRAY[@]}" -gt "1" ]]; then
            HTTAG="multiple-on"
        else
            :
        fi
    fi

    if [[ -z ${USRARRAY[@]} || -z ${HTPASS[@]} ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Empty response is not accepted. Please try again,"\
                " or see -h | --help | help${CLR}"
        exit 1
    else
        :
    fi
    IFS=$OIFS
}

usersudocheck(){
    if [[ "${#USRARRAY[@]}" != "${#ARRSDOCMD[@]}" ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- There are ${#USRARRAY[@]} users and ${#ARRSDOCMD[@]} sudo options."
        echo -e "             ${WHTE}These should be equal. Please try again, or see -h | --help | help${CLR}"
        exit 1
    else
        if [[ "${#USRARRAY[@]}" -gt "1" ]]
        then
            HTTAG="multiple-on"
        else
            :
        fi
    fi

    if [[ -z ${USRARRAY[@]} || -z ${ARRSDOCMD[@]} ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Empty response is not accepted. Please try again,"\
                " or see -h | --help | help${WHTE}"
        exit 1
    else
        :
    fi
}

usergroupcheck(){
    if [[ "${#USRARRAY[@]}" != "${#GRPARRAY[@]}"  ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- There are ${#USRARRAY[@]} users and ${#GRPARRAY[@]} groups."
        echo -e "             ${WHTE}These should be equal. Please try again, or see -h | --help | help${WHTE}"
        exit 1
    else
       if [[ "${#USRARRAY[@]}" -gt "1" ]]; then
           HTTAG="multiple-on"
        else
           :
        fi
    fi

    if [[ -z ${USRARRAY[@]} || -z ${GRPARRAY[@]} ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Empty response is not accepted. Please try again,"\
                " or see -h | --help | help${WHTE}"
        exit 1
    else
        :
    fi
}   

sudopasscheck(){
    if [[ "${#HTPASS[@]}" != "${#ARRSDOCMD[@]}"  ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- There are ${#HTPASS[@]} passwords and ${#ARRSDOCMD[@]} sudo options."
        echo -e "             ${WHTE}These should be equal. Please try again, or see -h | --help | help${WHTE}"
        exit 1
    else
        if [[ "${#HTPASS[@]}" -gt "1" ]]; then
            HTTAG="multiple-on"
        else
            :
        fi
    fi

    if [[ -z ${ARRSDOCMD[@]} || -z ${HTPASS[@]} ]]; then
        echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Empty response is not accepted. Please try again,"\
                " or see -h | --help | help${WHTE}"
        exit 1
    else
        :
    fi
}

showhashpass(){
    echo "Following hashes created:"
    for ((i=0; i<${#HTPASS[@]}; i++))
    do
        echo -e "${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: $(echo ${HTPASS[i]} | sed 's/REPLACE-TAG/\$/g')" 
    done
#    echo -e "${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}"
    separatesec
}


getauditinfo(){
# we pass this to an elif statement later on to determine which fields we want in the aduit 

    echo -en "Do you want to a full report or specific information? (f for full - s for specific) [f/s]"\
         "\n${L_GRN}|--${D_RD}*${CLR}${L_GRN}--|${CLR}: "
    read AUDITRSPNS
    case $AUDITRSPNS in
        [f-F]* )
            AUDITFLAGS="NULL"
            ;;
        [s-S]* )
            for i in  "sudoers" "local users" "local groups" "user expirey"
            do
                echo -en "${L_GRN}|--${S_BLUE} show ${i} ${CLR}${L_GRN}--|${CLR}[y/n]: "
                read rspnse
                if [[ "${rspnse}" = "y" || "${rspnse}" = "n" ]]
                then :
                else
                    echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Response is not accepted. Please try again."
                    exit 1
                fi
                intflags+=($rspnse)
             done
             if [[ "${intflags[0]}" == "y" ]];then
                 AUDITFLAGS+=('SUDO') 
             else
                 AUDITFLAGS+=('NULL')
             fi
             if [[ "${intflags[1]}" == "y" ]];then
                 AUDITFLAGS+=('LUSER')
             else
                 AUDITFLAGS+=('NULL')
             fi
             if [[ "${intflags[2]}" == "y" ]];then
                 AUDITFLAGS+=('LGROUP')
             else
                 AUDITFLAGS+=('NULL')
             fi
             if [[ "${intflags[3]}" == "y" ]];then
                 AUDITFLAGS+=('LEXPIRE')
             else
                 AUDITFLAGS+=('NULL')
             fi
             ;;
        * ) echo -e " ${D_RD}[ FAIL ]${CLR} -- ${WHTE}Response is not accepted. Please try again."
            exit 1
            ;;
    esac    
}

catchsummary(){
    # this will log everything to a temporary file for parsing later
    TMPRSLTS=$(mktemp tmp.XXXXXX-results)
    TCKTARR=($TCKT)
}

returnsummary(){
     #here we are determining how many devices we ran against, and adding them all to an array
    unset SER_LIST
    OIFS=$IFS
    IFS=$'\n'
    # because of the way the colors get passed and how grep reads the file we "HAVE" to cat it first
    # yes it is gross, and if you have a better way, please tell me
    SER_LIST=$(cat -v ${TMPRSLTS} | grep '^\^\[\[38;5;41m{~} \^\[\[38;5;231mDevice:' | awk '{print $3}')
    ASER_LIST=( ${SER_LIST} )

    # here is just the number of failures. we search for it and the device, so that the failure is listed
    # below the device, then we pipe it to sed where we match FAIL, then pull the line before, and print
    # device number
    unset ANFAILS
    NFAILS=$(cat -v ${TMPRSLTS} | egrep 'FAIL|^\^\[\[38;5;41m{~} \^\[\[38;5;231mDevice:' | \
        sed -n '/FAIL/{x;p;d};x' | awk '{print $NF}')
    ANFAILS=( ${NFAILS} )

    # All were doing here is displaying the number of servers failed and passed
    echo -e "\nSummary:\n------------------------\nThis task ran against"\
            "${L_GRN}${#ASER_LIST[@]}${CLR} server(s)\n"\
            "\n"\
            "[ ${D_RD}${#ANFAILS[@]}${CLR} ] Server(s) failed\n"\
            "[ ${L_GRN}$((${#ASER_LIST[@]}-${#ANFAILS[@]}))${CLR} ] Server(s) passed\n"
    
    if [[ ! -z ${ANFAILS[@]} ]]; then
        echo -e "Here are the failed devices:"
        for ((i=0; i<${#ANFAILS[@]}; i++)); do
            echo -e "${D_RD}[-]${CLR} $(echo "${ANFAILS[i]}" | sed 's/\^\[/\\e/g;s/\^M//g')"
        done
    else :
    fi
    
    IFS=$OIFS
    rm -f ${TMPRSLTS}
}

# Here we create a tmp file for the script to run in, then set the functions to copy it to
# the remote device, and then remove it after
# we also had to create a script to run the script, because the second device interprets $TMPSCRPT
# as a different variable ~ and this seemed to be the best way to store it across devices

TMPSCRIPT=$(mktemp tmp.XXXXXX)
RUNTMP="run-$0-script"

device_cooker(){
    for ((i=0; i<${#TCKTARR[@]}; i++)); do
        echo ${TCKTARR[i]} > ${0}-cookbook
    done
    sed -i 's/,/\n/g' $0-cookbook
    OHOSTNAME=$HOSTNAME
    CRTDIR=$PWD
    echo "/bin/bash ${HOME}/${TMPSCRIPT} \${@} && rm -f -- ${TMPSCRIPT} ${RUNTMP}" > ${RUNTMP}
    pssh -h ${0}-cookbook -i "scp ${OHOSTNAME}:${CRTDIR}/${TMPSCRIPT} . && scp ${OHOSTNAME}:${CRTDIR}/${RUNTMP} ."\
        >/dev/null 2>&1
}

device_cleaner(){
#    pssh -h ${0}-cookbook "sudo rm -f -- ${TMPSCRIPT}" >/dev/null 2>&1
    rm -vf -- ${0}-cookbook ${RUNTMP}
    ls | egrep "^tmp\.[a-zA-Z0-9]{6,}$" | xargs rm -f
}

########
#####
### This is where everything is processed. This script essentially stops at the end of the case.
### It pulls all the info we need from the functions above. Below this are all of the scripts that
### handle the tasks listed at the start. These are 'cut out' with sed into a temporary script which is
### copied and run through ssh on a server. The variables we caught with our functions above are 
### carefully crafted into arrays and passed onto the server as arguments for the scripts.
####
#######


SSHARGS="-h ${0}-cookbook -i \"sudo bash $HOME/${RUNTMP}"
Q_GREP="| grep -v '^\[[0-9]\] [0-9][0-9]' "
case $VARPATH in
    1 ) 
        getuserinfo
        getpassinfo
        gethashpass
        userpasscheck        
        getexpireinfo
        showhashpass
        getticketinfo
        separatesec

        echo -e "${WHTE}==================${CLR}"
        echo -e "${S_BLUE}Creating User(s):${CLR} ${L_GRN}$USRNME${CLR} ${S_BLUE}with Password(s):"\
                "${CLR} ${L_GRN}${PASSARRAY[@]}${CLR}"
        sed -n '/^### START Create User/,/^### END Create User/p' createuser > ${TMPSCRIPT}
        
        startrun
        if [[ ! -z ${HTTAG} ]]
        then
            ARGS=( ${HTTAG} ${USRNME} ${HTPASS[@]} ${expiretoken}) 
            VARARGS="${ARGS[@]}\""
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${VARARGS} ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        else
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${USRNME} ${HTPASS} ${expiretoken}\" ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        fi    
        finishrun
        ;;

    2 )
        getuserinfo
        getpassinfo
        gethashpass
        userpasscheck
        showhashpass
        getticketinfo
        separatesec

        echo -e "${WHTE}==================${CLR}"
        echo -e "${S_BLUE}Changing Password for User(s):${CLR} ${L_GRN}${USRNME}${CLR} ${S_BLUE}to"\
                " Password(s):${CLR} ${L_GRN}${PASSARRAY[@]}${CLR}"
        TMPSCRIPT=$(mktemp tmp.XXXXXX)
        sed -n '/^### START Change Users Password/,/^### END Change Users Password/p' changeuser > ${TMPSCRIPT}
        
        startrun
        if [[ ! -z ${HTTAG} ]]
        then
            ARGS=( ${HTTAG} ${USRNME} ${HTPASS[@]} )
            VARARGS="${ARGS[@]}\""
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${VARARGS} ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        else    
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${USRNME} ${HTPASS}\" ${Q_GREP} |& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        fi
        finishrun
        ;;

    3 )
        getuserinfo
        getsudoinfo
        getsudocase
        usersudocheck
        getticketinfo
        separatesec

        echo -e "${WHTE}==================${CLR}"
        echo -e "${S_BLUE}Giving User(s):${CLR} ${L_GRN}${USRNME}${CLR} ${S_BLUE}sudo permissions${CLR}"
        TMPSCRIPT=$(mktemp tmp.XXXXXX)
        sed -n '/^### START Give user Sudo Permissions/,/^### END Give user Sudo Permissions/p' sudouser > ${TMPSCRIPT}
        
        startrun  
        if [[ ! -z ${HTTAG} ]]
        then
            ARGS=( ${HTTAG} ${USRNME} ${ARRSDOCMD[@]} )
            VARARGS="${ARGS[@]}\""
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${VARARGS} ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        else
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${USRNME} ${ARRSDOCMD}\" ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        fi
        finishrun
        ;;

    4 )
        getuserinfo
        getpassinfo
        gethashpass
        userpasscheck
        showhashpass
        getsudoinfo
        getsudocase
        usersudocheck
        sudopasscheck
        getexpireinfo
        getticketinfo
        separatesec

        echo -e "${WHTE}==================${CLR}"
        echo -e "${S_BLUE}Creating User(s):${CLR} ${L_GRN}${USRNME}${CLR} ${S_BLUE}with Password(s):"\
                "${CLR} ${L_GRN}${PASSARRAY[@]}${CLR} ${S_BLUE}and sudo permissions${CLR}"
        TMPSCRIPT=$(mktemp tmp.XXXXXX)
        sed -n '/^### START Create a user with Sudo/,/^### END Create a user with Sudo/p' createsudouser > ${TMPSCRIPT}
        
        startrun
        if [[ ! -z ${HTTAG} ]]
        then
            ARGS=( ${HTTAG} ${USRNME} ${HTPASS[@]} ${ARRSDOCMD[@]} ${expiretoken} )
            VARARGS="${ARGS[@]}\""
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${VARARGS} ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        else
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${USRNME} ${HTPASS} ${SDOCMD} ${expiretoken}\" ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        fi
        finishrun
        ;;
    
    5 )
        getuserinfo
        getgroupinfo
        usergroupcheck
        getticketinfo
        separatesec

        echo -e "${WHTE}==================${CLR}"
        echo -e "${S_BLUE}Adding${CLR} ${L_GRN}${USRNME}${CLR} ${S_BLUE}to group(s)${CLR}"\
                " ${L_GRN}${GRPARRAY[@]}${CLR}"
        TMPSCRIPT=$(mktemp tmp.XXXXXX)
        sed -n '/^### START Add a user to a group/,/^### END Add a user to a group/p' groupuser > ${TMPSCRIPT}
        
        startrun
        if [[ ! -z ${HTTAG} ]]
        then
            ARGS=( ${HTTAG} ${USRNME} ${GRPARRAY[@]} )
            VARARGS="${ARGS[@]}\""
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${VARARGS} ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        else
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${USRNME} ${GRPARRAY}\" ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        fi
        finishrun
        ;;

    6 )
        getticketinfo
        getauditinfo
        separatesec
       
        echo -e "${WHTE}==================${CLR}"
        echo -e "${S_BLUE}Retrieving a report of:${CLR} ${L_GRN}Users - Sudo Access - Groups${CLR}"
        TMPSCRIPT=$(mktemp tmp.XXXXXX)
        sed -n '/^### START Return a list of active/,/^### END Return a list of active/p' audituser > ${TMPSCRIPT}
        
        startrun
        catchsummary
        device_cooker
        eval "pssh ${SSHARGS} ${AUDITFLAGS[@]}\" ${Q_GREP}|& tee ${TMPRSLTS}"
        returnsummary
        device_cleaner
        finishrun
        ;;

    7 )
        getgecosinfo
        getticketinfo
        separatesec
        
        echo -e "${WHTE}==================${CLR}"
        echo -e "${S_BLUE}Disabling User:${CLR} ${L_GRN}${USRNME}${CLR}"
        TMPSCRIPT=$(mktemp tmp.XXXXXX)
        sed -n '/^### START Disable a User/,/^### END Disable a User/p' disableuser > ${TMPSCRIPT}
        

        startrun
        if [[ ! -z ${HTTAG} ]]
        then
            ARGS=( ${HTTAG} ${USRNME} ${DISTCKT} )
            VARARGS="${ARGS[@]}\""
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${VARARGS} ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        else
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${USRNME} ${DISTCKT}\" ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        fi
        finishrun
        ;;

    8 )
        getuserinfo
        getgroupinfo
        usergroupcheck
        getticketinfo
        separatesec
    
        echo -e "${WHTE}==================${CLR}"
        echo -e "${S_BLUE}Removing${CLR} ${L_GRN}${USRNME}${CLR} ${S_BLUE}from group(s)${CLR} ${L_GRN}${GRPARRAY[@]}${CLR}"
        TMPSCRIPT=$(mktemp tmp.XXXXXX)
        sed -n '/^### START Remove user from group/,/^### END Remove user from group/p' rmgroupuser > ${TMPSCRIPT}
        
        startrun
        if [[ ! -z ${HTTAG} ]]
        then
            ARGS=( ${HTTAG} ${USRNME} ${GRPARRAY[@]} )
            VARARGS="${ARGS[@]}\""
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${VARARGS} ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        else
            catchsummary
            device_cooker
            eval "pssh ${SSHARGS} ${USRNME} ${GRPARRAY}\" ${Q_GREP}|& tee ${TMPRSLTS}"
            returnsummary
            device_cleaner
        fi
        finishrun
        ;;

    * )
        echo -e "${D_RD}[ ERROR ]${CLR} ${WHTE}The variable you passed${CLR} ${L_GRN}${VARPATH}"\
                "${CLR} ${WHTE}- is not recognized. Please try again.${CLR}"
        exit 1
        ;;
esac

# Just to make sure it exits cleanly
exit 0
