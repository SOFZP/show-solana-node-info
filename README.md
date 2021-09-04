# show-solana-node-info
### Complex (but protracted) script for solana node monitoring

## The simpiest instruction how to use it:

1. Move file to the server or instance with installed solana, do it as you can - with cli or gui :)
2. `chmod u+x ./show-solana-node-info.sh`
3. `./show-solana-node-info.sh` - if you run this script on your node

## You can use it on any instance with installed solana and to see information of any node in solana blockchain:

`./show-solana-node-info.sh <NODE_PUBKEY> <CLUSTER_ABBREVIATED>`
<NODE_PUBKEY> - pubkey of any node
<CLUSTER_ABBREVIATED> - `-ut` or `-ud` or `-um` or `-ul` for cluster

## Known issues:
1. Long time of execution. Planning to make progress bar for estimated time.
2. If you have poor internet connection, there can be errors while script executes some commands (error of time out)
3. If pubkey isn't belong to node, there will be some errors.
4. If cluster is `-ul` (also this is the default value) you will not see last rewards. Planning to read cluster from *config get*.

## Example
![My TDS node](screenshots/example1.png "My TDS node info")
