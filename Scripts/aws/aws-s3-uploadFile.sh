#!/bin/bash
help() {
    echo "$0: uploads specifc filename to provided environment"
    echo "Usage: $0 [-e ENVIRONMENT] [-f filename]"
}

if [[ "$#" -ne "4" ]]; then
  help
  exit 1
fi

while getopts ":e:f:" opt; do
  case $opt in
    e)
      env=$OPTARG
      case $env in
	e2e)
	  bucket=Producte2e
	;;
	tsodev)
	  bucket=Producttsodev
	;;
        sandbox)
	  bucket=Productsandbox
	;;
        prod)
	  bucket=Productprod
	;;
      esac
      ;;
    f)
      filename=$OPTARG
      ;;
    *)
      echo "Invalid option: -$OPTARG" >&2
      help
      exit 1
      ;;
  esac
done

echo "Uploading file $filename to bucket $bucket in environment $env !"
aws s3api put-object --bucket $bucket --key artifacts/$env/$filename --body $filename

aws s3api copy-object --copy-source $bucket/artifacts/$env/$filename --key artifacts/$env/chef-latest.tar.gz --bucket $bucket
