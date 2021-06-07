#!/bin/bash -x
set -eu -o pipefail

CF_RELEASE=${CF_RELEASE:-false}
AWS_KEY_NAME=${AWS_KEY_NAME:-cloudysteam}

if [[ $CF_RELEASE == "true" ]]; then
    git checkout v$OPENVIDU_VERSION
fi

export AWS_DEFAULT_REGION=us-east-2

DATESTAMP=$(date +%s)
TEMPJSON=$(mktemp -t cloudformation-XXX --suffix .json)

# Get Latest Ubuntu AMI id from specified region
# Parameters
# $1 Aws region

getUbuntuAmiId() {
    local AMI_ID=$(
        aws --region ${1} ec2 describe-images \
        --filters "Name=name,Values=*ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*" \
        --query "sort_by(Images, &CreationDate)" \
        | jq -r 'del(.[] | select(.ImageOwnerAlias != null)) | .[-1].ImageId'
    )
    echo $AMI_ID
}

AMIEUWEST1=$(getUbuntuAmiId 'eu-west-1')
AMIUSEAST2=$(getUbuntuAmiId 'us-east-2')

# Copy templates to feed
cp cfn-mkt-ov-ce-ami.yaml.template cfn-mkt-ov-ce-ami.yaml

## Setting Openvidu Version and Ubuntu Latest AMIs
if [[ ! -z ${AWS_KEY_NAME} ]]; then
  sed -i "s/      KeyName: AWS_KEY_NAME/      KeyName: ${AWS_KEY_NAME}/g" cfn-mkt-ov-ce-ami.yaml
else
  sed -i '/      KeyName: AWS_KEY_NAME/d' cfn-mkt-ov-ce-ami.yaml
fi
sed -i "s/AWS_KEY_NAME/${AWS_KEY_NAME}/g" cfn-mkt-ov-ce-ami.yaml
#sed -i "s/OPENVIDU_VERSION/${OPENVIDU_VERSION}/g" cfn-mkt-ov-ce-ami.yaml
#sed -i "s/OPENVIDU_RECORDING_DOCKER_TAG/${OPENVIDU_RECORDING_DOCKER_TAG}/g" cfn-mkt-ov-ce-ami.yaml
sed -i "s/AMIEUWEST1/${AMIEUWEST1}/g" cfn-mkt-ov-ce-ami.yaml
sed -i "s/AMIUSEAST2/${AMIUSEAST2}/g" cfn-mkt-ov-ce-ami.yaml

## OpenVidu AMI

# Copy template to S3
aws s3 cp cfn-mkt-ov-ce-ami.yaml s3://elasticbeanstalk-us-east-2-160178507710
TEMPLATE_URL=https://elasticbeanstalk-us-east-2-160178507710.s3.us-east-2.amazonaws.com/cfn-mkt-ov-ce-ami.yaml

# Update installation script
if [[ ${UPDATE_INSTALLATION_SCRIPT:-true} == "true" ]]; then
  # Avoid overriding existing versions
  # Only master and non existing versions can be overriden
  if [[ ${OPENVIDU_VERSION:-2.17.0} != "master" ]]; then
    INSTALL_SCRIPT_EXISTS=true
    aws s3api head-object --bucket elasticbeanstalk-us-east-2-160178507710 --key install_openvidu_2.17.0.sh || INSTALL_SCRIPT_EXISTS=false
    if [[ ${INSTALL_SCRIPT_EXISTS} == "true" ]]; then
      echo "Aborting updating s3://lasticbeanstalk-us-east-2-160178507710/install_openvidu_2.17.0.sh. File actually exists."
      exit 1
    fi
  fi
  aws s3 cp  ../docker-compose/install_openvidu.sh s3://elasticbeanstalk-us-east-2-160178507710/install_openvidu_2.17.0.sh --acl public-read
fi

aws cloudformation create-stack \
  --stack-name openvidu-ce-${DATESTAMP} \
  --template-url ${TEMPLATE_URL} \
  --disable-rollback

aws cloudformation wait stack-create-complete --stack-name openvidu-ce-${DATESTAMP}

echo "Getting instance ID"
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=openvidu-ce-${DATESTAMP}" | jq -r ' .Reservations[] | .Instances[] | .InstanceId')

echo "Stopping the instance"
aws ec2 stop-instances --instance-ids ${INSTANCE_ID}

echo "wait for the instance to stop"
aws ec2 wait instance-stopped --instance-ids ${INSTANCE_ID}

echo "Creating AMI" https://raw.githubusercontent.com/OpenVidu/openvidu/2.17.0
OV_RAW_AMI_ID=$(aws ec2 create-image --instance-id ${INSTANCE_ID} --name OpenViduServerCE-2.17.0-${DATESTAMP} --description "Openvidu Server CE" --output text)

echo "Cleaning up"
aws cloudformation delete-stack --stack-name openvidu-ce-${DATESTAMP}

# Wait for the instance
# Unfortunately, aws cli does not have a way to increase timeout
WAIT_RETRIES=0
WAIT_MAX_RETRIES=3
until [ "${WAIT_RETRIES}" -ge "${WAIT_MAX_RETRIES}" ]
do
   aws ec2 wait image-available --image-ids ${OV_RAW_AMI_ID} && break
   WAIT_RETRIES=$((WAIT_RETRIES+1)) 
   sleep 5
done

# Updating the template
sed "s/OV_AMI_ID/${OV_RAW_AMI_ID}/" CF-OpenVidu.yaml.template > CF-OpenVidu-2.17.0.yaml
sed -i "s/OPENVIDU_VERSION/2.17.0/g" CF-OpenVidu-2.17.0.yaml

# Update CF template
if [[ ${UPDATE_CF:-true} == "true" ]]; then
  # Avoid overriding existing versions
  # Only master and non existing versions can be overriden
  if [[ ${OPENVIDU_VERSION:-2.17.0} != "master" ]]; then
    CF_EXIST=true
    aws s3api head-object --bucket elasticbeanstalk-us-east-2-160178507710 --key CF-OpenVidu-2.17.0.yaml || CF_EXIST=false
    if [[ ${CF_EXIST} == "true" ]]; then
      echo "Aborting updating s3://aws.openvidu.io/CF-OpenVidu-2.17.0.yaml. File actually exists."
      exit 1
    fi
  fi
  aws s3 cp CF-OpenVidu-2.17.0.yaml s3://elasticbeanstalk-us-east-2-160178507710/CF-OpenVidu-2.17.0.yaml --acl public-read
fi

rm $TEMPJSON
rm cfn-mkt-ov-ce-ami.yaml
