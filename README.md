# V-Runs (Chain)

## Running
* AWS_REGION=us-west-1  bundle exec jets server
* bin/webpack-dev-server

## Deploy
To deploy need to be using us-west-1 as region

* jets webpacker:compile 
* AWS_REGION=us-west-1 jets deployG

## Add JS Packages
yarn add <package>  


Useful curl commands:
* curl -X DELETE localhost:8888/games/0e1741773eb4ee97afb91126c2869e3873bfb3df
* curl -X POST localhost:8888/games
* curl -X POST localhost:8888/games/3cfd157a4b97f97cd1ba8d68a5e9f4878d16a1cc/start

For commands needing cookies:
* curl -X POST -b cookies.txt --cookie-jar cookies.txt -d player=alex localhost:8888/games/3cfd157a4b97f97cd1ba8d68a5e9f4878d16a1cc/player



