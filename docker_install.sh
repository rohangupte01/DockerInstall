#To-do 
# 1) Mechanism to automatically download docker-ls if it doesn't exist
# 2) More customization for docker container
#   a) instance name (done)
#   b) mounting a volume (done)
# 3) Option to use a dockerfile [Although this makes the script pretty much useless]
# 4) Optimize loops 
# 5) Fix variable names (done)
# 6) Given all inputs create a Dockerfile so the user can use it for the future
# 7) Add code to show all running docker containers names (done)
# 8) Find a way to add concatenate commands to base docker run command (done)
# 9) The lsof commands will not work on windows
#   a) Maybe distinguish different OS at the beginning and then have different commands
#   b) or find a universal command that works on both 
# 10) Improve error handling for docker commands
# 11) Add durable sys support (done)
# 12) Add error trapping function (does not work when given wrong repository or version) (done)
# 13) ubuntu uses bash, linux uses sh. Find a way to make both work. 
# 14) Add users if they would like to add anything




#!/bin/bash
CheckPrereqs()
{
    myarr="zero"

    if [ ! -x "$(command -v docker)" ];
    then
        myarr="Please install docker before running this script"
    fi

    if [ ! -x "$(command -v git)" ];
    then
        #myarr+="Please install git before running this script"
        myarr[${#myarr[@]}]="Please install git before running this script"
    fi

    if [ ! -x "$(command -v docker-ls)" ];
    then
        #myarr+="Please install docker-ls before running this script. You can visit https://github.com/mayflower/docker-ls for installation instructions"
        myarr[${#myarr[@]}]="Please install docker-ls before running this script. You can visit https://github.com/mayflower/docker-ls for installation instructions"
        #include possiblity of install this for the user
        #installdockerls()
    fi 

    if [[ ${myarr[@]} != "zero" ]]
    then
        echo "Prerequisites missing in order for script to run":
        for value in "${myarr[@]}"
        do
            echo $value
        done
        exit
    fi
}

# Add numbers next to the products so users can select the number instead of typing the entire product
# The docker commands reports everything on one line, need a way to break up the line and read each 
#   product into the array
CheckRepository() 
{
    re='^[0-9]+$'
    declare -a avoid

    # List of words to not include when reporting output from docker-ls
    avoid=(requesting list . done repositories: )

    declare -a kits
    i=1
    repo=$(docker-ls repositories --registry https://containers.intersystems.com 2>&1)

    # Go through the list of kits and normalize the text to avoid unwanted characters and phrases
    for kit in ${repo[@]}
    do 
        bad=0

        # If we find a '-' or word in the avoid, then set bad = 1
        if [ $kit != '-' ]
        then
            for text in ${avoid[@]}
            do
                if [ $kit == $text ]
                then
                    bad=1
                fi
            done

            # Print out list of repositories 
            if [ $bad -eq 0 ]
            then 
                kits[$i]=$kit
                echo $i$") "${kits[$i]}
                let i++
            fi
        fi
    done

    echo "which product do you want to install? Copy a path listed above or select number. "
    read product

    # If user enter number, match it to the the repository 
    if [[ $product =~ $re ]]
    then
        product=${kits[$product]}
    fi
    echo $product
    result=$(docker-ls tags --registry https://containers.intersystems.com $product 2>&1)
    if [[ $? -eq 1 ]]
    then 
        echo $result
        CheckRepository
    fi
}

CheckTag()
{
    re='^[0-9]+$'
    avoid=(requesting list . done repository: tags: $product)
    i=1
    repo=$(docker-ls tags --registry https://containers.intersystems.com $product 2>&1)

    for kit in ${repo[@]}
    do 
        bad=0

        # If we find a '-' or word in the avoid, then set bad = 1
        if [ $kit != '-' ]
        then
            for text in ${avoid[@]}
            do
                if [ $kit == $text ]
                then
                    bad=1
                fi
            done

            # Print out list of repositories 
            if [ $bad -eq 0 ]
            then 
                kits[$i]=$kit
                echo $i$") "${kits[$i]}
                let i++
            fi
        fi
    done

    echo "which version do you want to install? Type '""back""' to return to list of repositories."
    read version

    # If user enter number, match it to the the version
    if [[ $version =~ $re ]]
    then
        version=${kits[$version]}
    fi
    

    if [[ $version == "back" ]]
    then
        unset version
        CheckRepository
        CheckTag
    
    fi
    docker-ls tag --registry https://containers.intersystems.com $product:$version
    if [[ $? -eq 1 ]]
    then
        echo "version does not exist. Try again"
        CheckTag
    fi 
    repository=" containers.intersystems.com/"${product}$":"${version}
    echo $repository
    
}

CheckName()
{
    same=0
    echo $'\nCurrently listed container names'

    containercount=$(docker ps -a| wc -l)
    if [[ $containercount -gt 1 ]]
    then
        docker inspect --format='{{.Name}}' $(docker ps -aq --no-trunc) | tr -d "/"
        namelist=($(docker inspect --format='{{.Name}}' $(docker ps -aq --no-trunc) | tr -d "/"))
        
        echo $'\nContainer name? (Leave blank for random name provided by docker)'
        read name

        if [ -z "$name" ]
        then    
            echo $'\nUsing a default docker name'
            dockerrun="docker container run -d"
        elif [ ! -z "$name" ]
        then
            for n in ${namelist[@]}
            do 
                if [ "$name" == $n ]
                then
                    echo $'\nName already in use. Pick another name'
                    CheckName
                    break
                else
                    dockerrun="docker container run -d --name $name"
                fi
            done
        fi
    else
        echo $'\nNo containers listed'
        echo $'\nContainer name?'
        read name
        dockerrun="docker container run -d --name $name"
    fi
}

CheckPorts()
{
    maxport=65535
    echo $dockerrun
    re='^[0-9]+$'
    distinct=0
    while [ $distinct -eq 0 ]
    do 
        echo $'\nsuper server port?'
        read superport
        myarr=($(lsof -PiTCP -sTCP:LISTEN | tr -d '*:'| tr -d 'localhost'| sed -e 's/\[[^][]*\]//g' | awk '{print $9}'))
        for port in ${myarr[@]}
        do 
            if ! [[ $superport =~ $re && "$superport" -le "$maxport" ]];
            then
                echo "please enter a valid port number" 
                distinct=0
                break
            elif [[ $port -eq $superport ]]
            then 
                echo "port in use, pick another port"
                distinct=0
                break
            else
                distinct=1
            fi
        done
    done


    while [ $distinct -eq 1 ]
    do 
        echo "web server port?"
        read webport
        for port in ${myarr[@]}
        do 
            if ! [[ $webport =~ $re && "$webport" -le "$maxport" ]];
            then
                echo "please enter a valid port number" 
                distinct=1
                break
            elif [[ ( $port -eq $webport ) || ( $webport -eq $superport ) ]]
            then
                echo "port in use, pick another port"
                distinct=1
                break
            else
                distinct=2
            fi
        done 
    done
    dockerrun="${dockerrun} -p $superport:51773 -p $webport:52773"
    echo $dockerrun
}

MountDurableSYS()
{
    echo "Mount a volume as Durable SYS? (yes or no)"
    read v
    if [[ "$v" == "yes" ]];
    then 
        echo "volume location on host?"
        read hostvolume

        echo "volume location to be mapped in container?"
        read dockervolume
    
        echo "full path of durablesys in container (/Volume/path)"
        read durablesys
        dockerrun="${dockerrun} -v $hostvolume:$dockervolume --env ISC_DATA_DIRECTORY=$durablesys"
   fi
}

# Runs docker run command with all the previous concatenated parameters
CreateContainer()
{
    dockerrun="$dockerrun$repository"
    echo "Running: "${dockerrun}

    #Runs docker command stored in $dockerrun variable
    eval $dockerrun
    rez=$?

    # If successful display tools to access container and IRIS instance. If unsuccessful, docker will display the error.
    if [ $rez -eq 0 ]
    then
        hostname=$(hostname)
        echo $'\nAccess the SMP at http://'$hostname':'$webport'/csp/sys/UtilHome.csp'
        echo $'\nTo access the container terminal: 'docker exec -it "$name" sh' '
        echo $'\nTo stop the container run: docker stop '"$name"''
        echo $'\nTo remove the container run: docker rm '$name'';
    fi
}


#Future plans are to try an automate dockerls installation.
installdockerls()
{
    if ! command -v docker-ls
    then
        echo "Would you like the script to install docker-ls? It is needed to access the intersystems docker repositories. Please enter yes or no"
        read answer
        if [[ $answer == "yes" ]]
        then
            #add mechanism to automatically download docker-ls if it doesn't exist on the system
            echo "Installing docker-ls command"
            git clone https://github.com/mayflower/docker-ls.git
            docker build -t docker-ls .
        else 
            echo "Please install docker-ls before running the script"
            exit
        fi 
    fi
}


#Check if system has all the prerequisites to run this script
CheckPrereqs

#List repositories and have user select a product
CheckRepository

#List product versions and have user select a version
CheckTag

#Show all running docker containers names 
CheckName

#Set ports to publish
CheckPorts

#Option to mount a volume as DurableSYS
MountDurableSYS

#Create the container
CreateContainer
