#!/bin/bash
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source $(pwd)/tencent_cloud.sh

OLD_IP=""
OLD_PING=""
OLD_SPEED=""
NEW_IP=""
NEW_PING=""
NEW_SPEED=""
TEST_URL="https://speed.cloudflare.com/__down?measId=1361084997055349&bytes=209715200"
RESULT_FILE="result.csv"
TEST_TXT="test.txt"
IPV4_TXT="proxy.txt"

HOST_NAME=""
API_ID=""
API_KEY=""

UPDATE="0"

while getopts ":h:i:k:u:" opt; do
  case $opt in
    h)
      HOST_NAME=$OPTARG
      ;;
    i)
      API_ID=$OPTARG
      ;;
    k)
      API_KEY=$OPTARG
      ;;
    u)
      UPDATE=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      exit -1
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      exit -2
      ;;
  esac
done

if [[ -z $HOST_NAME || -z $API_ID || -z $API_KEY ]]; then
  echo "Missing required options. -h, -i, -k must be provided."
  exit -3
fi

DOMAIN="${HOST_NAME##*.}"
remaining="${HOST_NAME%.*}"
SUB_DOMAIN="${remaining%%.*}"
DOMAIN="${remaining#*.}.$DOMAIN"

function speed_test() {
    local ipfile=$1
    local command="./CloudflareST_$(uname -m) -sl 1 -url ${TEST_URL} -o ${RESULT_FILE} -f ${ipfile}"
    local ip=""
    local speed=""
    local i=0
    while [[ $ip == "" && $i -lt 3 ]]; do
        $command
        # 获取最快 IP（从 result.csv 结果文件中获取第一个 IP）
        ip=$(sed -n "2,1p" $RESULT_FILE | awk -F, '{print $1}')
        speed=$(sed -n "2,1p" $RESULT_FILE | awk -F, '{print $NF}')
        (( i=i+1 ))
    done
}

echo "------------start------------"
echo HOST_NAME: $HOST_NAME
echo DOMAIN: $DOMAIN
echo SUB_DOMAIN: $SUB_DOMAIN

ret=$(tencent_get_record "$API_ID" "$API_KEY" "$DOMAIN" "$SUB_DOMAIN")

if [[ $? -ne 0 ]]; then
    echo get record failed!
    echo "------------end------------"
    exit $?
fi

recordid=$(echo $ret | awk -F " " '{print $1}')
OLD_IP=$(echo $ret | awk -F " " '{print $2}')
echo recordid: $recordid
echo recordip: $OLD_IP

echo "$OLD_IP/32" > $TEST_TXT

speed_test $TEST_TXT
OLD_PING=$(sed -n "2,1p" $RESULT_FILE | awk -F, '{print $(NF-1)}')
OLD_SPEED=$(sed -n "2,1p" $RESULT_FILE | awk -F, '{print $NF}')

wget -O txt.zip https://zip.baipiao.eu.org
tempdir=$(mktemp -d)
unzip txt.zip '*.txt' -d "${tempdir}"
for txtfile in "${tempdir}"/*.txt; do
    while IFS= read -r line; do
        echo "${line}/32"
    done < "${txtfile}"
done > $IPV4_TXT
rm -r "${tempdir}"
rm -f txt.zip

speed_test $IPV4_TXT
NEW_IP=$(sed -n "2,1p" $RESULT_FILE | awk -F, '{print $1}')
NEW_PING=$(sed -n "2,1p" $RESULT_FILE | awk -F, '{print $(NF-1)}')
NEW_SPEED=$(sed -n "2,1p" $RESULT_FILE | awk -F, '{print $NF}')

rm -f $TEST_TXT $IPV4_TXT $RESULT_FILE

if [[ $OLD_PING == "" ]]; then
    OLD_PING=1000
fi
if [[ $OLD_SPEED == "" ]]; then
    OLD_SPEED=0
fi

if [[ $NEW_PING == "" ]]; then
    NEW_PING=1000
fi
if [[ $NEW_SPEED == "" ]]; then
    NEW_SPEED=0
fi

echo old $OLD_IP ping ${OLD_PING}ms ${OLD_SPEED}MB/s
echo new $NEW_IP ping ${NEW_PING}ms ${NEW_SPEED}MB/s

if [[ $(echo "$OLD_SPEED == 0" | bc) -eq 1 ]]; then
    OLD_PING=1000
fi

if [[ $UPDATE == "1" && $(echo "$NEW_PING < $OLD_PING" | bc) -eq 1 && $(echo "$NEW_SPEED > $OLD_SPEED" | bc) -eq 1 ]]; then
    tencent_update_record "$API_ID" "$API_KEY" "$DOMAIN" "$SUB_DOMAIN" "$recordid" "$NEW_IP"
else
    echo "current ip speed is best!"
fi

echo ""
echo "------------end------------"
