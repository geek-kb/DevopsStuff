import groovy.json.*
def bucket = 'jenkins-and-kibana'
def url = 'http://es-logs.service.consul:9200/_cat/snapshots/'+bucket+'?format=json'
def connection = new URL("${url}").openConnection() as HttpURLConnection
def jsonResponse = new JsonSlurperClassic().parseText(connection.inputStream.text)
def result = []
jsonResponse.each { it ->
    if ((it['status'] == 'SUCCESS') && (it['id'].startsWith('snapshot_'))) {
        result.add(it['id'])
    }
}
return result
