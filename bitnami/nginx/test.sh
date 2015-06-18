#!/usr/bin/env bats

CONTAINER_NAME=bitnami-nginx-test
IMAGE_NAME=bitnami/nginx
SLEEP_TIME=2
VOL_PREFIX=/bitnami/nginx
HOST_VOL_PREFIX=/tmp/bitnami/$CONTAINER_NAME

# Check config override from host
setup() {
  mkdir -p $HOST_VOL_PREFIX
}

teardown() {
  if [ "$(docker ps -a | grep $CONTAINER_NAME)" ]; then
    docker rm -fv $CONTAINER_NAME
  fi
}

create_container(){
  docker run -itd --name $CONTAINER_NAME \
   --expose 81 $IMAGE_NAME
  sleep $SLEEP_TIME
}

add_vhost() {
  docker exec $CONTAINER_NAME sh -c "echo 'server { listen 0.0.0.0:81; location / { return 405; } }' > $VOL_PREFIX/conf/vhosts/test.conf"
}


@test "We can connect to the port 80 and 443" {
  create_container
  docker run --link $CONTAINER_NAME:nginx --rm bitnami/nginx curl -L -i http://nginx:80 | {
    run grep "200 OK"
    [ $status = 0 ]
  }

  docker run --link $CONTAINER_NAME:nginx --rm bitnami/nginx curl -L -i -k https://nginx:443 | {
    run grep "200 OK"
    [ $status = 0 ]
  }
}

@test "Returns default page" {
  create_container
  docker run --link $CONTAINER_NAME:nginx --rm bitnami/nginx curl -L -i http://nginx:80 | {
    run grep "It works!"
    [ $status = 0 ]
  }

  docker run --link $CONTAINER_NAME:nginx --rm bitnami/nginx curl -L -i -k https://nginx:443 | {
    run grep "It works!"
    [ $status = 0 ]
  }
}

@test "All the volumes exposed" {
  create_container
  docker inspect $CONTAINER_NAME | {
    run grep "\"Volumes\":" -A 3
    [[ "$output" =~ "$VOL_PREFIX/logs" ]]
    [[ "$output" =~ "$VOL_PREFIX/conf" ]]
    [[ "$output" =~ "/app" ]]
  }
}

@test "Vhosts directory is imported" {
  create_container
  add_vhost
  docker restart $CONTAINER_NAME
  sleep $SLEEP_TIME
  docker run --link $CONTAINER_NAME:nginx --rm bitnami/nginx curl -L -i http://nginx:81 | {
    run grep "405 Not Allowed"
    [ $status = 0 ]
  }
}
