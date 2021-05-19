# V-Runs (Chain)

## Running
```sh
chruby 2.5
AWS_REGION=us-west-2  bundle exec jets server
bin/webpack-dev-server
```

## Deploy
To deploy need to be using us-west-1 as region
May need also use ruby 2.5.
```
chruby 2.5
bundle exec jets webpacker:compile 
AWS_REGION=us-west-2 bundle exec jets deploy
```

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
x Some animation for CPU Players playing?
* Game log over -> highlight the space where the player played.
* CPU Player defensive calculation

x On lambda, cant switch teams
* Wild card symbols
x End game on draw
x Make cpu players take a few seconds to play.
  
* Make sure player ordering is correct with 3 teams, 2 per team (and ensure order in page is correct)

* Game Rooms 
Create a rooms table.  Rooms have a password and a name. to join, you enter the name and the password. 
The room ID is stored on all games created from that lobby (add to CREATE for ziddler/chain). 
  Add a secondary index to games tables (room_id, updated_at) (this lets us sort them within a room easily)
  


Options:
* HACKY auth 
INDEX:
- enter a name + password, set some cookie and try to show the room
  
SHOW:
- on showing the room, check the cookie - validate it against the hashed password and show the room if it matches.



# Room todos
* On /join, set the cookie either in javascipt.  OR, update the browser location to show url during :show render.


