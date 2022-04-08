#!/bin/bash


# Check to make sure the system has all the prerequistes needed to run the script
CheckPrereqs()
{
    myarr=""

    # Need docker installed
    if [ ! -x "$(command -v docker)" ];
    then
        myarr="Please install docker before running this script"
    fi

    # Need docker-ls installed
    if [ ! -x "$(command -v docker-ls)" ];
    then
        myarr[${#myarr[@]}]="Please install docker-ls before running this script. You can visit https://github.com/mayflower/docker-ls for installation instructions"
        dockerls=0
    fi 

    # Tell user which pre requisites they are missing
    if [[ ${myarr[@]} != "" ]]
    then
        echo "Prerequisites missing in order for script to run":
        for value in "${myarr[@]}"
        do
            echo $value
        done

        # Check if homebrew is installed. If so, then offer the user installation of docker-ls via homebrew from this script.
        which -s brew
        if [[ ($dockerls == 0)  && ($? == 0 ) ]]
        then
            echo "You have brew installed. This script can install docker-ls for you via brew. Type ""yes"" if you would like the script to install docker-ls"
            read answer
            if [[ $answer == "yes" ]]
            then
                brew install docker-ls
            else 
                echo "Please visit https://github.com/mayflower/docker-ls for docker-ls installation instuctions"
                exit
            fi
        else   
            exit
        fi
    fi
}

# List out InterSystems Repository
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


# Check if repo exists, if not call CheckRepository again and have user reselect 
    if [[ $? -eq 1 ]]
    then 
        echo $result
        CheckRepository
    fi
   
}


# List tags of selected product
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

            # Print out list of versions
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

    #Check if user wants to go back to Repository list
    if [[ $version == "back" ]]
    then
       back=1
    fi

    docker-ls tag --registry https://containers.intersystems.com $product:$version

    # Check if user input to see if it's a valid version
    if [[ $? -eq 1 ]]
    then
        if [[ $back -eq 1 ]]
        then 
            unset version
            CheckRepository
            CheckTag
        else 
            echo "version does not exist. Try again"
            CheckTag
        fi
    else
        echo "Are you sure you'd like to install $version?. Enter 'yes' to continue, or 'no' to return back to versions"
        read cont
        echo $cont
        t=0

        while [ $t -eq 0 ]
        do
            if [ $cont == "yes" ]
            then
            t=1
            docker-ls tag --registry https://containers.intersystems.com $product:$version
                if [[ $? -eq 1 ]]
                then
                    echo "version does not exist. Try again"
                    CheckTag
                    exit
                fi 
                repository=" containers.intersystems.com/"${product}$":"${version}
                echo $repository
            elif  [ $cont == "no" ]
            then 
                t=1
                CheckTag
            else 
                echo "Please enter yes or no"
                read cont
            fi 
        done
    fi

    repository=" containers.intersystems.com/"${product}$":"${version}
    echo $repository
    
}

# Check names of current containers on the system
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

        # Use default name provided by docker
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


# Ask user to enter superserver and webserver ports
# Check that the ports selected are not already in-use
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


# Ask user if they'd like to mount a DurableSYS volume
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
    
        echo "full path of durablesys folder in container (/path/folder_name)"
        read durablesys
        dockerrun="${dockerrun} --volume $hostvolume:$dockervolume --env ISC_DATA_DIRECTORY=$durablesys"

        echo "If license key is not in the durablesys path, would you like to copy it from an different directory? Enter 'yes' or 'no' "
        read keyanswer
        if [[ "$keyanswer" == "yes" ]]
        then 
            CopyLicenseKey
        fi
    else
         dockerrun="$dockerrun$repository"
   fi
}


#If user has a LicenseKey to enter
CopyLicenseKey()
{
    dockerrun="$dockerrun$repository"
    echo "Please make sure key is called: 'iris.key' "
    echo "please enter the full path including the key file name to copy from: "
    read keypath

    cp -f $keypath $hostvolume
            
    dockerrun="${dockerrun} --key '$dockervolume/iris.key'"


}

# Runs docker run command with all the previous concatenated parameters
CreateContainer()
{
    echo "Running: "${dockerrun}

    #Runs docker command stored in $dockerrun variable
    eval $dockerrun
    rez=$?


    # If successful display tools to access container and IRIS instance. If unsuccessful, docker will display the error.

    #find way to handle silent failures. run the inspect for status
    if [ $rez -eq 0 ]
    then
        containerid=$(docker container ps -a| awk '{print $1}' | awk 'NR==2')
        status=$(docker inspect --format="{{.State.Status}}" ''$containerid'')
        hostname=$(hostname)
        if [[ "$status" == "running" ]]
        then
            containername=$(docker inspect --format="{{.Name}}" ''$containerid'' | tr -d "/")
            echo $'\nAccess the SMP at http://'$hostname':'$webport'/csp/sys/UtilHome.csp'
            echo $'\nTo access the container terminal: 'docker exec -it "$containername" sh' '
            echo $'\nTo stop the container run: docker stop '"$containername"''
            echo $'\nTo remove the container run: docker rm '$containername'';
        else
            echo "Error creating container. Run 'docker logs '$containerid'' for more information"
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
