#!/usr/bin/env bash

REQUIRED_PKG="bc"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
  echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
  sudo apt-get --yes install $REQUIRED_PKG
fi

function WaitTransactionToBeCompleted() {
    HASH=${1}

    TRANSACTION_STATUS="unconfirmed."
    while [[ ${TRANSACTION_STATUS} != "confirmed" ]]; do
        TRANSACTION_STATUS=$(${BIN} wallet:transaction ${HASH} | grep "Status: " | sed "s/Status: //")
        if [[ ${TRANSACTION_STATUS} != "confirmed" ]]; then
            echo -e "hash: ${HASH}, transaction status: ${TRANSACTION_STATUS}."
            sleep 10
        else
            echo -e "hash: ${HASH}, transaction status: ${TRANSACTION_STATUS}.\n"
        fi
    done
}


function GetBalanceFunc() {
    ${BIN} wallet:balance | grep -o "[0-9]\+.[0-9]*" | tail -1
}


function MintFunc() {
    RESULT=$(echo "Y" | ${BIN} wallet:mint --name=${GRAFFITI} --metadata=${GRAFFITI}  --amount=1000 --fee=0.00000001 | tr -d '\0')
    CheckResultFunc "MINT" "${RESULT}"
}


function BurnFunc() {
    RESULT=$(echo "Y" | ${BIN} wallet:burn --assetId=${IDENTIFIER} --amount=500 --fee=0.00000001 | tr -d '\0')
    CheckResultFunc "BURN" "${RESULT}"
}


function SendFunc() {
    ADDRESS_TO_SEND="dfc2679369551e64e3950e06a88e68466e813c63b100283520045925adbe59ca"
    RESULT=$(echo "Y" | ${BIN} wallet:send --assetId=${IDENTIFIER} --amount 500 --to ${ADDRESS_TO_SEND} --memo "${GRAFFITI}" --fee=0.00000001 | tr -d '\0')
    CheckResultFunc "SEND" "${RESULT}"
}


function GetTransactionHashFunc() {
    INPUT=${1}
    HASH=$(echo ${INPUT} | grep -Eo "Transaction Hash: [a-z0-9]*" | sed "s/Transaction Hash: //")
    echo ${HASH}
}


function CheckResultFunc() {
    FUNC_RESULT="fail"

    FUNCTION_NAME=${1}
    FUNCTION_RESULT=${2}
    
    if [[ ${FUNCTION_RESULT} == *"Transaction Hash"* ]]; then
        FUNC_RESULT="success"
        echo -e "\n/////////////////// [ ${FUNCTION_NAME} | SUCCESS | #${FUNC_TRY} ] ///////////////////\n"
        WaitTransactionToBeCompleted $(GetTransactionHashFunc "${FUNCTION_RESULT}")

        if [[ ${FUNCTION_NAME} == "MINT" ]]; then
            IDENTIFIER=$(echo ${RESULT} | grep -Eo "Asset Identifier: [a-z0-9]*" | sed "s/Asset Identifier: //")
        fi
    else
        echo -e "\n/////////////////// [ ${FUNCTION_NAME} | FAIL | #${FUNC_TRY} ] ///////////////////\n${FUNCTION_RESULT}"
    fi
}


function TryUntilSuccessFunc() {
    FUNCTION=${1}

    FUNC_RESULT="fail"
    FUNC_TRY=0

    while [[ ${FUNC_RESULT} == "fail" ]]; do
        FUNC_TRY=$((FUNC_TRY + 1))
        ${FUNCTION}
    done
}



function MainFunc() {
    BIN=$(which ironfish)
    GRAFFITI=$(echo $(${BIN} config:get blockGraffiti) | sed 's/\"//g')

    if [ $(echo "$(GetBalanceFunc) > 0.00000003" | bc ) -eq 1 ]; then
        TryUntilSuccessFunc "MintFunc"
        TryUntilSuccessFunc "BurnFunc"
        TryUntilSuccessFunc "SendFunc"
    else
        echo "not enough balance. minimum required: \$IRON 0.00000003, but you have only: \$IRON $(GetBalanceFunc)."
    fi
}

MainFunc
