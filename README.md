# V-Runs (Chain)

## Running
```sh
AWS_REGION=us-west-1  bundle exec jets server
bin/webpack-dev-server
```

## Deploy
To deploy need to be using us-west-1 as region

* jets webpacker:compile 
* AWS_REGION=us-west-1 jets deploy

## Add JS Packages
yarn add <package>  


## Working TODO List
x Disable clicking/playing on taken spots.
x When CPU player goes first - have them play.  
x Game log
x Display sequence (in the Board, transform sequences to a Set/map from BoardI to team, then in Card its a quick check.)  
x Display suites as colored symbols
x Wilds
  x Display
  x  Backend handling: support is valid play
  *  CPU Support (later)  
* Some animation for CPU Players playing?
* Game log over -> highlight the space where the player played.
* CPU Player defensive calculation



