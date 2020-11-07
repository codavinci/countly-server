#!/bin/bash

#check if authentication is required
isAuth=$(mongo --eval "db.getUsers()" | grep -v "connecting" | grep "auth")

#check if we have previous upgrade needed
FEATVER=$(mongo admin --eval "printjson(db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } ).featureCompatibilityVersion)" --quiet);
VER=$(mongod -version | grep "db version" | cut -d ' ' -f 3 | cut -d 'v' -f 2)

if ! [ -z "$isAuth" ] ; then
    echo "Since authentication is enabled, we cannot verify if you need to run this upgrade script"
    echo ""
    echo "Please run this command with authentication parameters:"
    echo ""
    echo "mongo admin --eval \"db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 } )\""
    echo ""
    echo "and continue only if \"featureCompatibilityVersion\" is 4.2 "
    echo ""
    read -r -p "Is your \"featureCompatibilityVersion\" version is 4.2? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
    then
        echo "Continue upgrading"
    else
        echo "Stopping script"
        exit 0;
    fi

fi

if [ -x "$(command -v mongo)" ]; then
    if echo "$VER" | grep -q -i "4.4" ; then
        if echo "$FEATVER" | grep -q -i "4.2" ; then
            echo "run this command to ugprade to 4.4";
            echo "mongo admin --eval \"db.adminCommand( { setFeatureCompatibilityVersion: \\\"4.4\\\" } )\"";
        else
            echo "We already have version 4.4";
        fi
        exit 0;
    elif echo "$VER" | grep -q -i "4.2" ; then
        echo "Upgrading to MongoDB 4.4";
    else
        echo "Unsupported MongodB version $VER";
        echo "Upgrade to MongoDB 4.2 first and then run this script";
        exit 1;
    fi

    if [ -f /etc/redhat-release ]; then
        #uninstall mognodb
        yum erase -y mongodb-org mongodb-org-mongos mongodb-org-server mongodb-org-shell mongodb-org-tools
    fi

    if [ -f /etc/lsb-release ]; then
        #uninstall mognodb
        apt-get remove -y mongodb-org mongodb-org-mongos mongodb-org-server mongodb-org-shell mongodb-org-tools
    fi
fi

if [ -f /etc/redhat-release ]; then
    #install latest mongodb

    #select source based on release
	if grep -q -i "release 6" /etc/redhat-release ; then
        echo "[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/6/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc" > /etc/yum.repos.d/mongodb-org-4.4.repo
    elif grep -q -i "release 7" /etc/redhat-release ; then
        echo "[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc" > /etc/yum.repos.d/mongodb-org-4.4.repo
    fi
    yum install -y mongodb-org
fi

if [ -f /etc/lsb-release ]; then
    #install latest mongodb
	wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    UBUNTU_YEAR="$(lsb_release -sr | cut -d '.' -f 1)";

    if [ "$UBUNTU_YEAR" == "14" ]
    then
        echo "14"
		echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list ;
    elif [ "$UBUNTU_YEAR" == "16" ]
    then
        echo "16"
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list ;
    else
        echo "18"
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    fi
    apt-get update
    #install mongodb
    apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install mongodb-org --force-yes || (echo "Failed to install mongodb." ; exit)
fi

if [ -f /etc/redhat-release ]; then
    #mongodb might need to be started
    if grep -q -i "release 6" /etc/redhat-release ; then
        service mongod restart || echo "mongodb service does not exist"
    else
        systemctl restart mongod || echo "mongodb systemctl job does not exist"
    fi
fi

if [ -f /etc/lsb-release ]; then
    if [[ $(/sbin/init --version) =~ upstart ]]; then
        restart mongod || echo "mongodb upstart job does not exist"
    else
        systemctl restart mongod || echo "mongodb systemctl job does not exist"
    fi
fi

#nc not available on latest centos
#until nc -z localhost 27017; do echo Waiting for MongoDB; sleep 1; done
mongo --nodb --eval 'var conn; print("Waiting for MongoDB connection on port 27017. Exit if incorrect port"); var cnt = 0; while(!conn && cnt <= 300){try{conn = new Mongo("localhost:27017");}catch(Error){}sleep(1000);cnt++;}'

if ! [ -z "$isAuth" ] ; then
    echo "run this command with authentication to ugprade to 4.4"
    echo "mongo admin --eval \"db.adminCommand( { setFeatureCompatibilityVersion: \\\"4.4\\\" } )\""
elif ! mongo admin --eval "printjson(db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } ))" ; then
    echo "Could not connect to MongodB, run this command when Mongo is up and running"
    echo "mongo admin --eval \"db.adminCommand( { setFeatureCompatibilityVersion: \\\"4.4\\\" } )\""
else
    mongo admin --eval "printjson(db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } ))"
    mongo admin --eval "db.adminCommand( { setFeatureCompatibilityVersion: \"4.4\" } )"
    echo "Upgraded MongoDB to 4.4"
fi
