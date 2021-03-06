set -e 
echo 'Starting Ambari'
service ambari start

source ambari_util.sh

if [ -e '/opt/solr' ]
then
    echo 'Moving existing Solr'
	mv /opt/solr /opt/solr-$(date +%F-%H:%M)
fi

rpmdb --rebuilddb

echo '*** Stopping OOZIE....'
stop OOZIE

echo '*** Stopping Falcon....'
stop FALCON

echo '*** Starting Hive....'
startWait HIVE

sleep 3

echo '*** Starting Storm....'
startWait STORM

sleep 3

echo '*** Starting HBase....'
startWait HBASE

sleep 3

echo '*** Starting kafka....'
startWait KAFKA

sleep 3

KAFKA_HOME=/usr/hdp/current/kafka-broker
TOPICS=`$KAFKA_HOME/bin/kafka-topics.sh --zookeeper sandbox.hortonworks.com:2181 --list | wc -l`
if [ $TOPICS == 0 ]
then
	echo "No Kafka topics found...creating..."
	$KAFKA_HOME/bin/kafka-topics.sh --create --zookeeper sandbox.hortonworks.com:2181 --replication-factor 1 --partitions 1 --topic twitter_events	
fi

if [ ! -d '/root/hdp22-twitter-demo/logs' ]
then
	mkdir /root/hdp22-twitter-demo/logs
fi

find /root/hdp22-twitter-demo -iname '*.sh' | xargs chmod +x
echo "Installing mvn..."
/root/hdp22-twitter-demo/setup-scripts/install_mvn.sh > /root/hdp22-twitter-demo/logs/install_mvn.log
echo "Installing Solr..."
/root/hdp22-twitter-demo/setup-scripts/install_solr.sh > /root/hdp22-twitter-demo/logs/install_solr.log
echo "Installing Banana..."
/root/hdp22-twitter-demo/setup-scripts/install_banana.sh > /root/hdp22-twitter-demo/logs/install_banana.log
echo "Installing Phoenix"
/root/hdp22-twitter-demo/setup-scripts/install_phoenix.sh > /root/hdp22-twitter-demo/logs/install_phoenix.log

echo "Creating Phoenix tables..."
/root/hdp22-twitter-demo/fetchSecuritiesList/runcreatehbasetables.sh > /root/hdp22-twitter-demo/logs/runcreatehbasetables.log

echo "Creating dictionary..."
/root/hdp22-twitter-demo/dictionary/run_createdictionary.sh > /root/hdp22-twitter-demo/logs/run_createdictionary.log

echo "Creating Hive table..."
hive -f /root/hdp22-twitter-demo/stormtwitter-mvn/twitter.sql > /root/hdp22-twitter-demo/logs/create-hivetable.log

echo "Setup complete. Logs available under /root/hdp22-twitter-demo/logs"


