## Streaming workshop demo

This demo was part of a technical webinar workshop: "Real Time Monitoring with Hadoop" and "Search Workshop"

Slides and webinar recording are available at http://hortonworks.com/partners/learn/

#### Monitor Twitter stream for S&P 500 companies to identify & act on unexpected increases in tweet volume

- Ingest: 
Listen for Twitter streams related to S&P 500 companies 
- Processing:
  - Monitor tweets for unexpected volume
  - Volume thresholds managed in HBASE
- Persistence:
  - HDFS (for future batch processing)
  - Hive (for interactive query) 
  - HBase (for realtime alerts)
  - Solr/Banana (for search and reports/dashboards)
- Refine:
  -  Update threshold values based on historical analysis of tweet volumes

- Demo setup:
	- Either download and start prebuilt VM
	- Start HDP 2.2.4 sandbox and run provided scripts to setup demo 
	
##### Contents

1. [Prebuilt VM option](https://github.com/abajwa-hw/hdp22-twitter-demo#prebuilt-vm-setup-option)
1. [Setup demo manually option](https://github.com/abajwa-hw/hdp22-twitter-demo#setup-demo-manually-option)
2. [Kafka basics - optional](https://github.com/abajwa-hw/hdp22-twitter-demo#kafka-basics---optional)
3. [Run demo](https://github.com/abajwa-hw/hdp22-twitter-demo#run-twitter-demo) to monitor Tweets about S&P 500 securities in realtime
4. [Observe results](https://github.com/abajwa-hw/hdp22-twitter-demo#observe-results) in HDFS, Hive, Solr/Banana, HBase
5. [Import data into BI tools - optional](https://github.com/abajwa-hw/hdp22-twitter-demo#import-data-to-bi-tool-via-odbc-for-analysis---optional) after copying into ORC table
6. [Other things to try - optional](https://github.com/abajwa-hw/hdp22-twitter-demo#other-things-to-try-analyze-any-kind-of-tweet---optional)
7. [Reset demo](https://github.com/abajwa-hw/hdp22-twitter-demo#reset-demo)



##### Setup demo 

These setup steps are only needed first time

- Download HDP 2.2.4.2 sandbox VM image from [Hortonworks website](http://hortonworks.com/products/hortonworks-sandbox/) 
- Find the IP address of the VM and add an entry into your machines hosts file e.g.
```
192.168.191.241 sandbox.hortonworks.com sandbox    
```
- Connect to the VM via SSH (password hadoop)
```
ssh root@sandbox.hortonworks.com
```
- **Edit /etc/hosts of sandbox** to change the "localhost" entry to point to IP address instead of 127.0.0.1, then restart network service. This is needed because kafka binds to IP address
```
vi /etc/hosts

service network restart
```

- Pull latest code/scripts
```
git clone https://github.com/abajwa-hw/hdp22-twitter-demo.git	
```
- Add users to global allow policies in Ranger
  - Start Ranger and login to http://sandbox.hortonworks.com:6080 (admin/admin)
  ```
  service ranger-admin start
  ```
  - "HDFS Global Allow": add group root to this policy - by opening http://sandbox.hortonworks.com:6080/#!/hdfs/1/policy/2
  - "HBase Global Allow": add group hadoop to this policy - by opening http://sandbox.hortonworks.com:6080/#!/hbase/3/policy/8 
  - "Hive Global Tables Allow": add user admin to this policy - by opening http://sandbox.hortonworks.com:6080/#!/hive/2/policy/5
    - Note you will need to first create an admin user - by opening http://sandbox.hortonworks.com:6080/#!/users/usertab
  - ![Image](../master/screenshots/Rangerpolicies.png?raw=true)
    
- Twitter4J requires you to have a Twitter account and obtain developer keys by registering an "app". Create a Twitter account and app and get your consumer key/token and access keys/tokens:
https://apps.twitter.com > sign in > create new app > fill anything > create access tokens
- Then enter the 4 values into the file below in the sandbox
```
vi /root/hdp22-twitter-demo/kafkaproducer/twitter4j.properties
oauth.consumerKey=
oauth.consumerSecret=
oauth.accessToken=
oauth.accessTokenSecret=
```

- Run below to setup demo (one time): start Ambari/HBase/Kafka/Storm and install maven, solr, banana, phoenix-may take 10 min
```
cd /root/hdp22-twitter-demo
./setup-demo.sh
```

##### Kafka basics - (optional)

```
#check if kafka already started
ps -ef | grep kafka

#if not, start kafka
nohup /usr/hdp/current/kafka-broker/bin/kafka-server-start.sh /usr/hdp/current/kafka-broker/config/server.properties &

#create topic
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --zookeeper sandbox.hortonworks.com:2181 --replication-factor 1 --partitions 1 --topic test

#list topic
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper sandbox.hortonworks.com:2181 --list | grep test

#start a producer and enter text on few lines
/usr/hdp/current/kafka-broker/bin/kafka-console-producer.sh --broker-list sandbox.hortonworks.com:6667 --topic test

#start a consumer in a new terminal your text appears in the consumer
/usr/hdp/current/kafka-broker/bin/kafka-console-consumer.sh --zookeeper sandbox.hortonworks.com:2181 --topic test --from-beginning

#delete topic
/usr/hdp/current/kafka-broker/bin/kafka-run-class.sh kafka.admin.DeleteTopicCommand --zookeeper sandbox.hortonworks.com:2181 --topic test
```

#####  Run Twitter demo 

#####  Start demo

- (Optional) Review the list of stock symbols whose Twitter mentiones we will be tracking
http://en.wikipedia.org/wiki/List_of_S%26P_500_companies

- (Optional) Generate securities csv from above page and review the securities.csv generated. The last field is the generated tweet volume threshold 
```
/root/hdp22-twitter-demo/fetchSecuritiesList/rungeneratecsv.sh
cat /root/hdp22-twitter-demo/fetchSecuritiesList/securities.csv
```

- (Optional) step for future runs: can add other stocks/trending topics to csv to speed up tweets (no trailing spaces). Find these at http://mobile.twitter.com/trends
```
sed -i '1i$HDP,Hortonworks,Technology,Technology,Santa Clara CA,0000000001,5' /root/hdp22-twitter-demo/fetchSecuritiesList/securities.csv
sed -i '1i#mtvstars,MTV Stars,Entertainment,Entertainment,Hollywood CA,0000000001,40' /root/hdp22-twitter-demo/fetchSecuritiesList/securities.csv
```

- (Optional) Open connection to HBase via Phoenix and check you can list tables. Notice securities data was imported and alerts table is empty
```
/usr/hdp/current/phoenix-client/bin/sqlline.py  sandbox.hortonworks.com:2181:/hbase-unsecure
!tables
select * from securities;
select * from alerts;
select * from dictionary;
!q
```

- (Optional) check Hive table schema where we will store the tweets for later analysis
```
hive -e 'desc tweets_text_partition'
```

- Start storm topology to generate alerts into an HBase table for stocks whose tweet volume is higher than threshold this will also read tweets into Hive/HDFS/local disk/Solr/Banana. The first time you run below, maven will take 15min to download dependent jars
```
cd /root/hdp22-twitter-demo
./start-demo.sh
```

- (Optional) Other modes the topology could be started in future runs if you want to clean the setup or run locally (not on the storm running on the sandbox)
```
cd /root/hdp22-twitter-demo/stormtwitter-mvn
./runtopology.sh runOnCluster clean
./runtopology.sh runLocally skipclean
```

- open storm UI and confirm topology was created
http://sandbox.hortonworks.com:8744/

- In a new terminal, compile and run kafka producer to generate tweets containing first 400 stock symbols values from csv
```
/root/hdp22-twitter-demo/kafkaproducer/runkafkaproducer.sh
```

##### Observe results



- Open storm UI and drill into it to view statistics for each Bolt, 
'Acked' columns should start increasing
http://sandbox.hortonworks.com:8744/

- Open Files view and see the tweets getting stored:
http://sandbox.hortonworks.com:8080/#/main/views/FILES/0.1.0/MyFiles

![Image](../master/screenshots/Files-view.png?raw=true)

- Open Hive table via Hive view. Notice tweets appear in the Hive table that was created:
http://sandbox.hortonworks.com:8080/#/main/views/HIVE/0.2.0/MyHive

![Image](../master/screenshots/Hive-view.png?raw=true)

- Open Banana UI and view/search tweet summary and alerts:
http://sandbox.hortonworks.com:8983/banana

![Image](../master/screenshots/Banana-view.png?raw=true)

  - For more details on the Banana dashboard panels are built, refer to the underlying [json](https://github.com/abajwa-hw/hdp22-twitter-demo/blob/master/default.json) file that defines all the panels 
  - In case you don't see any tweets, try changing to a different timeframe on timeline (e.g. by clicking 24 hours, 7 days etc). If there is a time mismatch between the VM and your machine, the tweets may appear at a different place on the timeline than expected.
 
- Run a query in Solr to look at tweets/hashtags/alerts. Click on 'Query' and enter a query under 'q'. 
Examples are doctype_s:tweet and text_t:AAPL. You can choose an output format under 'wt' and click 'Execute Query'.
http://sandbox.hortonworks.com:8983/solr/#/tweets

![Image](../master/screenshots/Solr-screenshot.png?raw=true)

- You can also search using Solr's APIs. The below displays all alerts in JSON format
http://sandbox.hortonworks.com:8983/solr/tweets/select?q=*%3A*&df=id&wt=json&fq=doctype_s:alert
  - The SolrBolt code showing how the data gets into Solr is shown [here](https://github.com/abajwa-hw/hdp22-twitter-demo/blob/master/stormtwitter-mvn/src/main/java/hellostorm/SolrBolt.java)
![Image](../master/screenshots/Solr-apisearch-screenshot.png?raw=true)

- Open connection to HBase via Phoenix and notice alerts were generated
```
/usr/hdp/current/phoenix-client/bin/sqlline.py  sandbox.hortonworks.com:2181:/hbase-unsecure
select * from alerts
```
![Image](../master/screenshots/Alerts-screenshot.png?raw=true)

- Notice tweets written to sandbox filesystem via FileSystem bolt
```
vi /tmp/Tweets.xls
```

###### To stop collecting tweets:

- kill the storm topology to stop processing tweets
```
storm kill Twittertopology
```
- To stop producing tweets, press Control-C in the terminal you ran runkafkaproducer.sh 


##### Import data to BI Tool via ODBC for analysis - optional

- Create ORC table and copy the tweets over:
```
hive -f /root/hdp22-twitter-demo/stormtwitter-mvn/createORC.sql
```

- View the contents of the ORC table created:
http://sandbox.hortonworks.com:8000/beeswax/table/default/tweets_orc_partition_single

![Image](../master/screenshots/Hue-screenshot.png?raw=true)

- Grant select access to user hive to the ORC table 
```
hive -e 'grant SELECT on table tweets_orc_partition_single to user hive'
```
- On windows VM create an ODBC connector called sandbox with below settings: 
```
	Host=<IP address of sandbox VM>
	port=10000 
	database=default 
	Hive Server type=Hive Server 2 
	Mechanism=User Name 
	UserName=hive 
```
![Image](../master/screenshots/ODBC-screenshot.png?raw=true)

- Import data from tweets_orc_partition_single table into Excel over ODBC
Data > From other Datasources > From dataconnection wizard > ODBC DSN > sandbox  > tweets_orc_partition_single > Finish > Yes > OK

![Image](../master/screenshots/Excel-screenshot.png?raw=true)

- Create some visualizations using PowerCharts (e.g. plotting tweets with coordinates on map)
![Image](../master/screenshots/PowerChart-screenshot.png?raw=true)



##### Other things to try: Analyze any kind of tweet - optional


- Instead of filtering on tweets from certain stocks/hashtags, you can also consume all 
tweets returned by TwitterStream API and re-run runkafkaproducer.sh
Note that in this mode a large volume of tweets is generated so you should stop the kafka 
producer after 20-30s to avoid overloading the system
It also may take a few minutes after stopping the kafka producer before all the tweets 
show up in Banana/Hive
```
mv /root/hdp22-twitter-demo/fetchSecuritiesList/securities.csv /root/hdp22-twitter-demo/fetchSecuritiesList/securities.csv.bak
```

- To filter tweets based on geography open below file and uncomment [this line](https://github.com/abajwa-hw/hdp22-twitter-demo/blob/master/kafkaproducer/TestProducer.java#L176) and re-run runkafkaproducer.sh
```
vi /root/hdp22-twitter-demo/kafkaproducer/TestProducer.java
/root/hdp22-twitter-demo/kafkaproducer/runkafkaproducer.sh
```

##### Reset demo

- This empties out the demo related HDFS folders, Hive table, Solr core, Banana webapp
and stops the storm topoogy
```
/root/hdp22-twitter-demo/reset-demo.sh
```

- If kafka keeps sending your topology old tweets, you can also clear kafka queue
```
zookeeper-client
rmr /group1
```
