# DockerInstall

Currently only support on mac

This script provides an api to easily create docker containers with intersystems images. This script relies on docker-ls. If you have brew installed on mac, the script can automatically download docker-ls for you. Otherwise, you can download it here:

https://github.com/mayflower/docker-ls
 
 
To run the script, change to the directory where the script is and enter: ./docker_install.sh 

You will need to be logged into the Intersystems container registry. The steps to do so can be found here: https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=PAGE_containerregistry#PAGE_containerregistry_authenticate


This script allows you to specific a DurableSYS mount. Below is an example of the prompt and what path you should put in each:


Volume location on host?

volume or directory path that will be the host for DurableSYS on local machine

EX: /Users/rgupte/durablesys



volume location to be mapped in container?

volume or directory path that will be the host for DURABLESYS on the docker container

EX: /usr/durablesys


full path of durablesys folder in container (/path/folder_name)

Folder within the volume or directory path that will contain all the InterSystems files wihtin the container:

EX: /usr/durablesys/test





