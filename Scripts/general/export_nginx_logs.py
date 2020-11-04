#!/usr/bin/env python3
# This script exports nginx-ingress-controller logs from elasticsearch and uploads them to s3.
# Script by Itai Ganot 2020
import argparse
import logging
import errno
import json
import os
import companydevopstools.tools.functions as tools
from companydevopstools.tools.aws import upload_to_s3
from datetime import datetime
from fsplit.filesplit import Filesplit

MAX_RESULTS = 10000
SCROLL_KEEP_SEARCH_ALIVE = "5m"
s3_bucket_name = 'company-elastic-nginx-logs' # This is the destination bucket which contains the gzip'ed logs
# per BI team's request
fsplit_size = 2147483648  # 2Gb in bytes
fs = Filesplit()
log_prefix = 'nginx-ingress-controller'
elasticsearch_auth = ()

aws_access_key_id = ''
aws_secret_access_key = ''


def api_call(auth, base_url, data_json, headers, uri, http_verb, return_output=False, output_to_json=True):
    url = "{}/{}".format(base_url, uri)
    try:
        response = tools.exe_api(url=url,
                                 http_verb=http_verb,
                                 auth=auth,
                                 data=data_json,
                                 headers=headers)
        if response.status_code != 200:
            print(response.content)
            print(response.status_code)
            raise Exception("Failed to run api:" + url)
        if return_output is True:
            if output_to_json:
                return json.loads(response.content.decode())
            else:
                return response.content.decode()
    except Exception:
        raise Exception("Failed to run api:" + url)


def get_all_indices(elasticsearch_url, log_prefix):
    logging.info("get all indices")
    uri = "_cat/indices/{}*?h=index".format(log_prefix)
    http_verb = "GET"
    headers = {'Content-Type': 'application/json'}
    result = api_call(elasticsearch_auth, elasticsearch_url, None, headers, uri, http_verb, return_output=True,
                      output_to_json=False)
    return result


def set_read_only_allow_delete(elasticsearch_url, index_name):
    logging.info("Set read_only_allow_delete to false")
    uri = "{}/_settings".format(index_name)
    headers = {'Content-Type': 'application/json'}
    data_json = '{ "index": { "blocks": { "read_only_allow_delete": "false" } }}'
    http_verb = "PUT"
    api_call(elasticsearch_auth, elasticsearch_url, data_json, headers, uri, http_verb)


def set_index_max_result(elasticsearch_url, index_name):
    logging.info("Set max_result_window to {}".format(MAX_RESULTS))
    uri = "{}/_settings".format(index_name)
    headers = {"Content-Type": "application/json"}
    data_json = '{ "index": { "max_result_window": "' + str(MAX_RESULTS) + '" }}'
    http_verb = "PUT"
    api_call(elasticsearch_auth, elasticsearch_url, data_json, headers, uri, http_verb)


def verify_index_is_healthy(elasticsearch_url, index_name):
    logging.info("verify index is healthy")
    uri = '_cat/indices/{}?h=health'.format(index_name)
    headers = {"Content-Type": "application/json"}
    http_verb = "GET"
    response = api_call(elasticsearch_auth, elasticsearch_url, None, headers, uri, http_verb, return_output=True,
                        output_to_json=False)
    decoded_response = response.strip()
    if decoded_response in ['yellow', 'green']:
        return True
    with open('unhealthy_indices.txt', 'a+', encoding='utf-8') as f:
        f.write(index_name)
        f.write('\n')
    return False


def create_directory_structure(index_name, region_name):
    date_str = datetime.strptime(index_name.split('-')[3], '%Y.%m.%d')
    date = date_str.date()
    year = date.year
    month = date.month
    day = date.day
    path = os.getcwd()
    full_path = path + '/' + region_name + '/' + str(year) + '/' + str(month) + '/' + str(day)
    try:
        os.makedirs(full_path)
        print("Successfully created directory {}".format(full_path))
    except OSError as exc:
        if exc.errno != errno.EEXIST:
            raise
        print("Directory {} already exists!".format(full_path))
    finally:
        return full_path


def get_scroll_id(elasticsearch_url, index_name, full_path):
    logging.info("Run first API call to get initial scroll id")
    uri = '{}/_search?scroll={}'.format(index_name, SCROLL_KEEP_SEARCH_ALIVE)
    headers = {"Content-Type": "application/json"}
    data_json = '{ "size": "' + str(MAX_RESULTS) + '", "query":{"match": {"log.file.path": "/tmp/nginx-logs/access.log"}}}'
    http_verb = "POST"
    response = api_call(elasticsearch_auth, elasticsearch_url, data_json, headers, uri, http_verb, return_output=True)
    num_of_lines = 0
    scroll_id = response["_scroll_id"]
    results = response["hits"]["hits"]
    if len(results):
        for result in results:
            if "message" in result["_source"] is not "":
                with open(full_path + '/' + index_name + '.log', "w", encoding='utf8') as file:
                    file.write(result["_source"]["message"] + "\n")
    logging.info("Got next scroll_id: {}".format(scroll_id))
    print('Now pulling data from index {}, this may take some time...'.format(index_name))
    # count = 0
    while scroll_id is not None:
        # count += 1
        # if count < 2:
        #     break
        uri = '_search/scroll'.format(SCROLL_KEEP_SEARCH_ALIVE)
        headers = {'Content-Type': 'application/json'}
        data_json = '{ "scroll" : "' + SCROLL_KEEP_SEARCH_ALIVE + '", "scroll_id" : "' + scroll_id + '" }'
        http_verb = "POST"
        response = api_call(elasticsearch_auth, elasticsearch_url, data_json, headers, uri, http_verb,
                            return_output=True)
        results = response["hits"]["hits"]
        if len(results):
            for result in results:
                if "message" in result["_source"] is not "":
                    with open(full_path + '/' + index_name + '.log', "a+", encoding='utf8') as file:
                        try:
                            file.write(result["_source"]["message"] + "\n")
                        except Exception as e:
                            print('Failing line in index: {}, error: {}'.format(index_name, e))
                            raise
                else:
                    logging.info('All logs pulled from index {}'.format(index_name))
                    print('No more logs to pull')
                    break
            num_of_lines += len(results)
            scroll_id = response["_scroll_id"]
        else:
            scroll_id = None
        logging.info("Got next scroll_id: {}".format(scroll_id))


def main():
    # Arg Parse #
    parser = argparse.ArgumentParser()
    parser.add_argument("--region", type=str, required=True, help="region to process")
    parser.add_argument("-v", "--verbose", action="store_true", help="set verbose level")
    parser.add_argument("-d", "--debug", action="store_true", help="set DEBUG level")
    args = parser.parse_args()
    # Arg Parse #

    region_name = args.region
    elasticsearch_url = "http://company-saas-{}-efk-elasticsearch-client.company-saas-{}:9200".format(region_name,
                                                                                                  region_name)
    # elasticsearch_url = 'http://localhost:9200'

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
        logging.debug("Hi, I am a company export_nginx_logs script.")

    all_indices = get_all_indices(elasticsearch_url, log_prefix).split('\n')
    all_indices = [ index_name for index_name in all_indices if index_name != "" ]
    s3_creds = {"aws_access_key_id": aws_access_key_id,
                "aws_secret_access_key": aws_secret_access_key}
    healthy_indices = [index_name for index_name in all_indices if verify_index_is_healthy(elasticsearch_url,
                                                                                           index_name)]
    for i, index_name in enumerate(healthy_indices):
        print('Processing index number {}/{}'.format(i+1, len(healthy_indices)))
        full_path = create_directory_structure(index_name, region_name)
        index_path = '{}/{}'.format(full_path, index_name)
        if os.path.isfile(index_path + '.done'):
            print('Index name {} has already been processed, continuing'.format(index_name))
            continue
        set_read_only_allow_delete(elasticsearch_url, index_name)
        set_index_max_result(elasticsearch_url, index_name)
        get_scroll_id(elasticsearch_url, index_name, full_path)
        log_index_path = index_path + '.log'
        if os.path.getsize(log_index_path) > fsplit_size:
            fs.split(file=log_index_path, split_size=fsplit_size, output_dir='{}/'.format(full_path))
        for root, dirs, files in os.walk("{}".format(full_path)):
            for filename in files:
                if filename.endswith('.csv'):
                    continue
                if filename.startswith('{}_'.format(index_name)):
                    date_str = datetime.strptime(filename.split('-')[3].split('_')[0], '%Y.%m.%d')
                else:
                    date_str = datetime.strptime(filename.split('-')[3][:-4], '%Y.%m.%d')
                date = date_str.date()
                year = date.year
                month = date.month
                day = date.day
                os.system('gzip {}/{}'.format(full_path, filename))
                upload_to_s3(src='{}/{}'.format(full_path,
                                                filename + '.gz'),
                             dest='{}/{}/{}/{}/{}/{}'.format(s3_bucket_name, region_name,
                                                             year,
                                                             month,
                                                             day,
                                                             filename + '.gz'),
                             creds=s3_creds)
                os.remove('{}/{}.gz'.format(full_path, filename))
        open('{}.done'.format(index_path), 'a').close()


    if args.verbose:
        print("Set verbose mode")
        print("INFO: args.region is {}".format(region_name))

    # default=INFO
    logging.getLogger().setLevel(logging.INFO)


if __name__ == "__main__":
    main()
