#!/bin/bash
#Show Approximate Vote Credits

pushd `dirname ${0}` > /dev/null || exit 1

CYAN='\033[0;36m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NOCOLOR='\033[0m'

ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'



# start of see schedule block
# modified from https://github.com/Vahhhh/solana/blob/main/see-schedule.sh -BIG THANKS!!!

#from https://stackoverflow.com/a/58617630OD
function durationToSeconds () {
  set -f
  normalize () { echo $1 | tr '[:upper:]' '[:lower:]' | tr -d "\"\\\'" | sed 's/years\{0,1\}/y/g; s/months\{0,1\}/m/g; s/days\{0,1\}/d/g; s/hours\{0,1\}/h/g; s/minutes\{0,1\}/m/g; s/min/m/g; s/seconds\{0,1\}/s/g; s/sec/s/g;  s/ //g;'; }
  local value=$(normalize "$1")
  local fallback=$(normalize "$2")

  echo $value | grep -v '^[-+*/0-9ydhms]\{0,30\}$' > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    >&2 echo Invalid duration pattern \"$value\"
  else
    if [ "$value" = "" ]; then
      [ "$fallback" != "" ] && durationToSeconds "$fallback"
    else
      sedtmpl () { echo "s/\([0-9]\+\)$1/(0\1 * $2)/g;"; }
      local template="$(sedtmpl '\( \|$\)' 1) $(sedtmpl y '365 * 86400') $(sedtmpl d 86400) $(sedtmpl h 3600) $(sedtmpl m 60) $(sedtmpl s 1) s/) *(/) + (/g;"
      echo $value | sed "$template" | bc
    fi
  fi
  set +f
}

function slotDate () {
  local SLOT=${1}
  local SLOT_DIFF=`echo "${SLOT}-${CURRENT_SLOT}" | bc`
  local DELTA=`echo "(${SLOT_LEN_SEC}*${SLOT_DIFF})/1" | bc`
  local SLOT_DATE_SEC=`echo "${NOW_SEC} + ${DELTA}" | bc`
  local DATE_TEXT=`TZ='UTC-3' date +"%F %T" -d @${SLOT_DATE_SEC}`
  echo "${DATE_TEXT}"
}

function slotColor() {
  local SLOT=${1}
  local COLOR=`
    if (( ${SLOT:-0} <= ${CURRENT_SLOT:-0} )); then
      echo "${RED}old< "
    else
      echo "${GREEN}new> "
    fi`
  echo -e "${COLOR}"
}

function see_shedule() {

	local DEFAULT_SOLANA_ADRESS1=`echo $(solana address)`
	local DEFAULT_CLUSTER1='-ul'

	local THIS_SOLANA_ADRESS1=${1:-$DEFAULT_SOLANA_ADRESS1}
	local SOLANA_CLUSTER1=' '${2:-$DEFAULT_CLUSTER1}' '

	local NOW=`TZ='UTC-3' date +"%F %T"`
	local NOW_SEC=`date +%s`
	local SCHEDULE=`solana ${SOLANA_CLUSTER1} leader-schedule | grep ${THIS_SOLANA_ADRESS1}`

	local FIRST_SLOT=`echo -e "$EPOCH_INFO" | grep "Epoch Slot Range: " | cut -d '[' -f 2 | cut -d '.' -f 1`
	local LAST_SLOT=`echo -e "$EPOCH_INFO" | grep "Epoch Slot Range: " | cut -d '[' -f 2 | cut -d '.' -f 3 | cut -d ')' -f 1`
	local CURRENT_SLOT=`echo -e "$EPOCH_INFO" | grep "Slot: " | cut -d ':' -f 2 | cut -d ' ' -f 2`
	local EPOCH_LEN_TEXT=`echo -e "$EPOCH_INFO" | grep "Completed Time" | cut -d '/' -f 2 | cut -d '(' -f 1`
	local EPOCH_LEN_SEC=$(durationToSeconds "${EPOCH_LEN_TEXT}")
	local SLOT_LEN_SEC=`echo "scale=10; ${EPOCH_LEN_SEC}/(${LAST_SLOT}-${FIRST_SLOT})" | bc`
	local SLOT_PER_SEC=`echo "scale=10; 1.0/${SLOT_LEN_SEC}" | bc`
	local COMPLETED_SLOTS=`echo -e "${SCHEDULE}" | awk -v cs="${CURRENT_SLOT:-0}" '{ if ( ! -z "$1" ) if ($1 <= cs) { print }}' | wc -l`
	local REMAINING_SLOTS=`echo -e "${SCHEDULE}" | awk -v cs="${CURRENT_SLOT:-0}" '{ if ( ! -z "$1" ) if ($1 > cs) { print }}' | wc -l`
	local TOTAL_SLOTS=`echo -e "${SCHEDULE}" | wc -l`

	echo "${NOW}"
	echo "Speed: ${SLOT_PER_SEC} slots per second"
	echo " Time: ${SLOT_LEN_SEC} seconds per slot"
	echo "My Slots ${COMPLETED_SLOTS}/${TOTAL_SLOTS} (${REMAINING_SLOTS} remaining)"
	echo
	echo "${EPOCH_INFO}"
	echo
	echo -e "${CYAN}Start:   `slotDate ${FIRST_SLOT}`${NOCOLOR}"
	echo "${SCHEDULE}" | sed 's/|/ /' | awk '{print $1}' | while read in; do
	COLOR=`slotColor ${in}`
	echo -e "${COLOR}$in `slotDate ${in}`${NOCOLOR}";
	done
	echo -e "${CYAN}End:     `slotDate ${LAST_SLOT}`${NOCOLOR}"
}

# end of see schedule block



DEFAULT_SOLANA_ADRESS=`echo $(solana address)`
DEFAULT_CLUSTER='-ul'

THIS_SOLANA_ADRESS=${1:-$DEFAULT_SOLANA_ADRESS}
SOLANA_CLUSTER=' '${2:-$DEFAULT_CLUSTER}' '

EPOCH_INFO=`solana ${SOLANA_CLUSTER} epoch-info`
SOLANA_VALIDATORS=`solana ${SOLANA_CLUSTER} validators`
YOUR_VOTE_ACCOUNT=`echo -e "${SOLANA_VALIDATORS}" | grep ${THIS_SOLANA_ADRESS} | sed 's/  */ /g' | cut -d ' ' -f 3`
THIS_SOLANA_VALIDATOR_INFO=`solana ${SOLANA_CLUSTER} validator-info get | awk '$0 ~ sadddddr {do_print=1} do_print==1 {print} NF==0 {do_print=0}' sadddddr=$THIS_SOLANA_ADRESS`
NODE_NAME=`echo -e "${THIS_SOLANA_VALIDATOR_INFO}" | grep 'Name: ' | sed 's/Name//g' | tr -s ' '`
SOLANA_VERSION=`echo -e "${SOLANA_VALIDATORS}" | grep -A 999999999 Skip | grep -B 999999999 Skip | grep -v Skip | grep ${THIS_SOLANA_ADRESS} | sed 's/(/ /g'| sed 's/)/ /g' | tr -s ' ' | sed 's/ /\n/g' | grep -v % | grep -i -v [a-z⚠-] | egrep '\.+[[:digit:]]\.+[[:digit:]]+$' | awk '{print ($1)}'`

SFDP_STATUS=`solana-foundation-delegation-program status ${THIS_SOLANA_ADRESS} | grep 'State: ' | sed 's/State: //g'`
COLOR_SFDP_STATUS=`
    if [[ "${SFDP_STATUS}" == "Approved" ]];
	then
      echo "${GREEN}"
    else
      echo "${LIGHTPURPLE}"
    fi`
SFDP_STATUS_STRING=`echo -e "State: ${COLOR_SFDP_STATUS}${SFDP_STATUS}${NOCOLOR}"`
SFDP=`solana-foundation-delegation-program status ${THIS_SOLANA_ADRESS} | grep -v "State: "`

NODE_WITHDRAW_AUTHORITY=`solana ${SOLANA_CLUSTER} vote-account ${YOUR_VOTE_ACCOUNT} | grep 'Withdraw' | awk '{print $NF}'`

TOTAL_ACTIVE_STAKE=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep 'Active Stake' | sed 's/Active Stake: //g' | sed 's/ SOL//g' | awk '{n += $1}; END{print n}' | bc`
TOTAL_STAKE_COUNT=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep 'Active Stake' | sed 's/Active Stake: //g' | sed 's/ SOL//g' | grep '' -c`

ACTIVATING_STAKE=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep 'Activating Stake: ' | sed 's/Activating Stake: //g' | sed 's/ SOL//g' | awk '{n += $1}; END{print n}' | bc`
ACTIVATING_STAKE_COUNT=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep 'Activating Stake: ' | sed 's/Activating Stake: //g' | sed 's/ SOL//g' | grep '' -c`
DEACTIVATING_STAKE=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep -B1 -i 'deactivates' | grep 'Active Stake' | sed 's/Active Stake: //g' | sed 's/ SOL//g' | awk '{n += $1}; END{print n}' | bc`
DEACTIVATING_STAKE_COUNT=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep -B1 -i 'deactivates' | grep 'Active Stake' | sed 's/Active Stake: //g' | sed 's/ SOL//g' | grep '' -c`

NO_MOVING_STAKE=`echo "${TOTAL_ACTIVE_STAKE:-0} ${DEACTIVATING_STAKE:-0}" | awk '{print $1 - $2}' | bc`

TOTAL_ACTIVE_STAKE_COUNT=`echo "${TOTAL_STAKE_COUNT:-0} ${ACTIVATING_STAKE_COUNT:-0}" | awk '{print $1 - $2}'`

BOT_ACTIVE_STAKE=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep -B7 -E "mvines|mpa4abUk" | grep 'Active Stake' | sed 's/Active Stake: //g' | sed 's/ SOL//g' | awk '{n += $1}; END{print n}' | bc`
BOT_ACTIVE_STAKE_CLR=`echo -e "${BOT_ACTIVE_STAKE:-0}" | awk '{if(NR=0) print 0; else print'} | awk '{ if ($1 > 5) print gr$1" SOL"nc; else print rd$1" SOL"nc; fi }' gr=$GREEN rd=$RED nc=$NOCOLOR`
BOT_ACTIVE_STAKE_COUNT=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep -B7 -E "mvines|mpa4abUk" | grep 'Active Stake' | sed 's/Active Stake: //g' | sed 's/ SOL//g' | grep '' -c`

SELF_ACTIVE_STAKE=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep -B7 'Withdraw Authority: '${NODE_WITHDRAW_AUTHORITY} | grep 'Active Stake' | sed 's/Active Stake: //g' | sed 's/ SOL//g' | bc | awk '{n += $1}; END{print n}'`
SELF_ACTIVE_STAKE_CLR=`echo -e "${SELF_ACTIVE_STAKE:-0}" | awk '{if(NR=0) print 0; else print'} | awk '{ if ($1 >= 100) print gr$1" SOL"nc; else print rd$1" SOL"nc; fi }' gr=$GREEN rd=$RED nc=$NOCOLOR`
SELF_ACTIVE_STAKE_COUNT=`solana ${SOLANA_CLUSTER} stakes ${YOUR_VOTE_ACCOUNT} | grep -B7 'Withdraw Authority: '${NODE_WITHDRAW_AUTHORITY} | grep 'Active Stake' | sed 's/Active Stake: //g' | sed 's/ SOL//g' | bc | grep '' -c`

OTHER_ACTIVE_STAKE=`echo "${TOTAL_ACTIVE_STAKE:-0} ${BOT_ACTIVE_STAKE:-0} ${SELF_ACTIVE_STAKE:-0}" | awk '{print $1 - $2 - $3}' | bc`
OTHER_ACTIVE_STAKE_COUNT=`echo "${TOTAL_ACTIVE_STAKE_COUNT:-0} ${BOT_ACTIVE_STAKE_COUNT:-0} ${SELF_ACTIVE_STAKE_COUNT:-0}" | awk '{print $1 - $2 - $3}'`

IDACC_BALANCE=`solana ${SOLANA_CLUSTER} balance ${THIS_SOLANA_ADRESS} | sed 's/ SOL//g' `
VOTEACC_BALANCE=`solana ${SOLANA_CLUSTER} balance ${YOUR_VOTE_ACCOUNT}`

IS_DELINKED=`solana ${SOLANA_CLUSTER} validators | grep ⚠️ | if (grep ${THIS_SOLANA_ADRESS} -c)>0; then echo -e "WARNING: ${RED}THIS NODE IS DELINKED\n\rconsider to check catchup, network connection and/or messages from your datacenter${NOCOLOR}"; else >/dev/null; fi`

YOUR_CREDITS=`solana ${SOLANA_CLUSTER} vote-account ${YOUR_VOTE_ACCOUNT} | grep -A 4 History | grep -A 2 epoch | grep credits/slots | cut -d ' ' -f 4 | cut -d '/' -f 1 | bc`
YOUR_CREDITS_PLACE=`solana validators ${SOLANA_CLUSTER} --sort=credits -r -n | grep ${THIS_SOLANA_ADRESS} | sed 's/⚠️/ /g' | awk '{print ($1)}' | sed 's/[[:blank:]]*$//'`
ALL_CREDITS_PLACES=`solana validators ${SOLANA_CLUSTER} --sort=credits -r -n | grep -A 999999999 Skip | grep -B 999999999 Skip | grep -v Skip | sed 's/[()⚠️]/ /g' | tr -s ' ' | tac | egrep -m 1 . | awk {'print $1'}`
ALL_CLUSTER_CREDITS_LIST=`solana ${SOLANA_CLUSTER} validators | grep -A 999999999 Skip | grep -B 999999999 Skip | grep -v Skip | sed 's/(/ /g'| sed 's/)/ /g' | tr -s ' ' | sed 's/ /\n\r/g' | grep -v % | grep -i -v [a-z⚠️-] | egrep '^.{2,7}$' | grep -v -E '\.+[[:digit:]]\.+[[:digit:]]+$' | grep -v -E '^.{2,3}$'`
SUM_CLUSTER_CREDITS=`echo -e "${ALL_CLUSTER_CREDITS_LIST}" | awk '{n += $1}; END{print n}'`
COUNT_CLUSTER_VALIDATORS=`echo -e "${ALL_CLUSTER_CREDITS_LIST}" | wc -l | bc`
CLUSTER_CREDITS=`echo -e "$SUM_CLUSTER_CREDITS" "$COUNT_CLUSTER_VALIDATORS" | awk '{print ($1/$2)}' `


CLUSTER_SKIP=`echo -e "${SOLANA_VALIDATORS}" | grep 'Average Stake-Weighted Skip Rate' | sed 's/  */ /g' | cut -d ' ' -f 5 | cut -d '%' -f 1`

ALL_SLOTS=`solana ${SOLANA_CLUSTER} leader-schedule | grep ${THIS_SOLANA_ADRESS} -c | awk '{if ($1==0) print 1; else print $1;}'`
SKIPPED_COUNT=`solana ${SOLANA_CLUSTER} -v block-production | grep ${THIS_SOLANA_ADRESS} | grep SKIPPED -c`
NON_SKIPPED_COUNT=`solana ${SOLANA_CLUSTER} -v block-production | grep ${THIS_SOLANA_ADRESS} | grep SKIPPED -v -c | awk '{ if ($1 > 0) print $1-1; else print 0; fi}'`

SCHEDULE1=`solana ${SOLANA_CLUSTER} leader-schedule | grep ${THIS_SOLANA_ADRESS} | tr -s ' ' | cut -d' ' -f2`
CURRENT_SLOT1=`echo -e "$EPOCH_INFO" | grep "Slot: " | cut -d ':' -f 2 | cut -d ' ' -f 2`
COMPLETED_SLOTS1=`echo -e "${SCHEDULE1}" | awk -v cs1="${CURRENT_SLOT1:-0}" '{ if ( ! -z "$1" ) if ($1 <= cs1) { print }}' | wc -l`
REMAINING_SLOTS1=`echo -e "${SCHEDULE1}" | awk -v cs1="${CURRENT_SLOT1:-0}" '{ if ( ! -z "$1" ) if ($1 > cs1) { print }}' | wc -l`

YOUR_SKIPRATE=`solana ${SOLANA_CLUSTER} -v block-production | grep ${THIS_SOLANA_ADRESS} | sed -n -e 1p | sed 's/  */ /g' | sed '/^#\|^$\| *#/d' | cut -d ' ' -f 6 | cut -d '%' -f 1 | awk '{print $1}'`


TIME_NOW=`see_shedule ${THIS_SOLANA_ADRESS} ${SOLANA_CLUSTER} | sed -n -e 1p`
END_OF_EPOCH=`see_shedule ${THIS_SOLANA_ADRESS} ${SOLANA_CLUSTER} | tail -n1 | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' | sed 's/End: /End of epoch:/g' | tr -s ' '`
NEAREST_SLOTS=`see_shedule ${THIS_SOLANA_ADRESS} ${SOLANA_CLUSTER} | grep -m1 -A11 "new>" | sed -n -e 1p -e 5p -e 9p | sed 's/End: /End of epoch:/g' | sed 's/new> //g' | tr -s ' ' | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g'`
LAST_BLOCK=`see_shedule ${THIS_SOLANA_ADRESS} ${SOLANA_CLUSTER} | grep "old<" | tail -n1 | sed 's/old< //g' | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g'`
LAST_BLOCK_STATUS=`solana ${SOLANA_CLUSTER} -v block-production | grep ${THIS_SOLANA_ADRESS} | tail -n2 | tr -s ' ' | sed 's/ /\n\r/g' | sed '/^$/d' | grep -i 'skipped' -c | awk {'if ($1==0) print "DONE"; else print "SKIPPED"'}`
COLOR_LAST_BLOCK=`
    if [[ "${LAST_BLOCK_STATUS}" == "SKIPPED" ]];
	then
      echo "${RED}"
    else
      echo "${GREEN}"
    fi`
	
LAST_REWARDS=`solana ${SOLANA_CLUSTER} vote-account --with-rewards --num-rewards-epochs 5 ${YOUR_VOTE_ACCOUNT} | grep -A10 'Reward Slot' | sed 's/Reward Slot/Reward_Slot/g' | awk '{print $1"\t"$2"\t"$3}'`


echo -e "${GREEN}"
echo -e "Time now: ${TIME_NOW:-''} ${NOCOLOR}" | awk 'length > 30'

echo -e "${CYAN}"
echo -e "Epoch Progress ${NOCOLOR}"

echo "$EPOCH_INFO" | grep 'Epoch: '
echo "$EPOCH_INFO" | grep 'Epoch Completed Percent'
echo "$EPOCH_INFO" | grep 'Epoch Completed Time'
echo -e "${NOCOLOR}$END_OF_EPOCH ${NOCOLOR}"


echo -e "${CYAN}"
echo -e "This Node${NODE_NAME} ${NOCOLOR}"

echo -e "${IS_DELINKED}" | awk 'length > 5'

echo -e "Identity: ${THIS_SOLANA_ADRESS}"

if (( $(bc<<<"scale=0;${IDACC_BALANCE:-0} >= 15.0") )); then
	echo -e "Identity Balance: ${GREEN}${IDACC_BALANCE:-0} SOL${NOCOLOR}"
else
	echo -e "Identity Balance: ${RED}${IDACC_BALANCE:-0} SOL${NOCOLOR}"
fi

echo -e "VoteKey: ${YOUR_VOTE_ACCOUNT}"
echo -e "VoteKey Balance: ${VOTEACC_BALANCE}"
echo -e "Stake: Total(${TOTAL_ACTIVE_STAKE_COUNT:-0}) ${TOTAL_ACTIVE_STAKE:-0} SOL / From Bot(${BOT_ACTIVE_STAKE_COUNT:-0}) ${BOT_ACTIVE_STAKE_CLR} / Self-Stake(${SELF_ACTIVE_STAKE_COUNT:-0}) ${SELF_ACTIVE_STAKE_CLR} / Other(${OTHER_ACTIVE_STAKE_COUNT:-0}) ${OTHER_ACTIVE_STAKE} SOL"
echo -e "Stake Moving: no-moving ${NO_MOVING_STAKE:-0} SOL / activating  ${ACTIVATING_STAKE:-0} SOL / deactivating ${DEACTIVATING_STAKE:-0} SOL"
echo -e "Solana version: " | tr -d '\r\n' && echo -e "${SOLANA_VERSION}"


echo -e "${CYAN}"
echo -e "Foundation Delegation Program Status ${NOCOLOR}"
echo -e "${SFDP_STATUS_STRING}"
echo -e "${SFDP}"

echo -e "${CYAN}"
echo -e "Vote-Credits ${NOCOLOR}"

echo -e "Average cluster credits: ${CLUSTER_CREDITS:-0} (minus grace 35%: $(bc<<<"scale=2;${CLUSTER_CREDITS:-0}*0.65"))"

if (( $(bc<<<"scale=0;${YOUR_CREDITS:-0} >= ${CLUSTER_CREDITS:-0}*0.65"))); then
  echo -e "${GREEN}Your credits: ${YOUR_CREDITS} (Good)${NOCOLOR}"
else
  echo -e "${RED}Your credits: ${YOUR_CREDITS} (Bad)${NOCOLOR}"
fi
echo -e "Your epoch credit rating: # ${YOUR_CREDITS_PLACE}/ ${ALL_CREDITS_PLACES} (${COUNT_CLUSTER_VALIDATORS} with non-zero credits)"


echo -e "${CYAN}"
echo -e "Skip Rate ${NOCOLOR}"

echo -e "Average cluster skiprate: ${CLUSTER_SKIP}% (plus grace 30%: $(bc<<<"scale=2;${CLUSTER_SKIP:-0}+30")%)"

if (( $(bc<<<"scale=2;${YOUR_SKIPRATE:-0} <= ${CLUSTER_SKIP:-0}+30"))); then
  echo -e "${GREEN}Your skiprate: ${YOUR_SKIPRATE:-0}% (Good) - Done: ${NON_SKIPPED_COUNT:-0}, Skipped: ${SKIPPED_COUNT:-0}${NOCOLOR}"
else
  echo -e "${RED}Your skiprate: ${YOUR_SKIPRATE:-0}% (Bad) - Done: ${NON_SKIPPED_COUNT:-0}, Skipped: ${SKIPPED_COUNT:-0}${NOCOLOR}"
fi

if (("${COMPLETED_SLOTS1:-0}" != '1' && "${ALL_SLOTS:-0}" != '1')); then

	echo "Your Slots ${COMPLETED_SLOTS1:-0}/${ALL_SLOTS:-0} (${REMAINING_SLOTS1:-0} remaining)"


	#min-skip
	if (( $(bc<<<"scale=2;${SKIPPED_COUNT:-0}*100/${ALL_SLOTS:-1} <= ${CLUSTER_SKIP:-0}+30") )); then
		echo -e "Your Min-Possible Skiprate is ${GREEN}$(bc<<<"scale=2;${SKIPPED_COUNT:-0}*100/${ALL_SLOTS:-1}")%${NOCOLOR} (if all remaining slots will be done)"
	else
		echo -e "Your Min-Possible Skiprate is ${RED}$(bc<<<"scale=2;${SKIPPED_COUNT:-0}*100/${ALL_SLOTS:-1}")%${NOCOLOR} (if all remaining slots will be done)"
	fi

	#max-skip
	if (( $(bc<<<"scale=2;(${ALL_SLOTS:-0}-${NON_SKIPPED_COUNT:-0})*100/${ALL_SLOTS:-1} <= ${CLUSTER_SKIP:-0}+30") )); then
		echo -e "Your Max-Possible Skiprate is ${GREEN}$(bc<<<"scale=2;(${ALL_SLOTS:-0}-${NON_SKIPPED_COUNT:-0})*100/${ALL_SLOTS:-1}")%${NOCOLOR} (if all remaining slots will be skipped)"
	else
		echo -e "Your Max-Possible Skiprate is ${RED}$(bc<<<"scale=2;(${ALL_SLOTS:-0}-${NON_SKIPPED_COUNT:-0})*100/${ALL_SLOTS:-1}")%${NOCOLOR} (if all remaining slots will be skipped)"
	fi



	echo -e "${CYAN}"
	echo -e "Block Production ${NOCOLOR}"

	if (( $(bc<<<"scale=2;${COMPLETED_SLOTS1:-0} > 0"))); then
		echo -e "Last Block: ${COLOR_LAST_BLOCK}${LAST_BLOCK} ${LAST_BLOCK_STATUS}${NOCOLOR}"
	else
		echo -e "This node did not produce any blocks yet"
	fi

	if (( $(bc<<<"scale=2;${REMAINING_SLOTS1:-0} > 0"))); then
		echo -e "Nearest Slots (4 blocks each):"
		echo -e "${GREEN}${NEAREST_SLOTS}${NOCOLOR}"
	else
		echo -e "This node will not have new blocks in this epoch"
	fi
	
else
	echo -e "${LIGHTPURPLE}This node don't have blocks in this epoch${NOCOLOR}"
fi


echo -e "${CYAN}"
echo -e "Last Rewards ${NOCOLOR}"
echo -e "${LAST_REWARDS:-${LIGHTPURPLE}No rewards yet ${NOCOLOR}}"

echo -e "${NOCOLOR}"

popd > /dev/null || exit 1